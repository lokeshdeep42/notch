import Darwin
import Foundation

/// A point-in-time reading of this process's own resource use, straight from the kernel.
/// Read on demand (when the panel opens) — never on a timer.
public struct CostSample: Equatable, Sendable {
    public var cpuSeconds: Double
    public var wakeups: UInt64
    public var footprintBytes: UInt64
    /// Seconds since `markLaunch()`.
    public var uptime: TimeInterval

    public init(cpuSeconds: Double, wakeups: UInt64, footprintBytes: UInt64, uptime: TimeInterval) {
        self.cpuSeconds = cpuSeconds
        self.wakeups = wakeups
        self.footprintBytes = footprintBytes
        self.uptime = uptime
    }

    private static var launchUptime: TimeInterval = ProcessInfo.processInfo.systemUptime

    /// Call once at launch so averages cover the whole session.
    public static func markLaunch() {
        launchUptime = ProcessInfo.processInfo.systemUptime
    }

    public static func current() -> CostSample? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        let cpu = seconds(usage.ru_utime) + seconds(usage.ru_stime)

        var power = task_power_info()
        var powerCount = mach_msg_type_number_t(
            MemoryLayout<task_power_info>.size / MemoryLayout<natural_t>.size
        )
        let powerResult = withUnsafeMutablePointer(to: &power) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(powerCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_POWER_INFO), $0, &powerCount)
            }
        }
        let wakeups: UInt64 = powerResult == KERN_SUCCESS
            ? power.task_interrupt_wakeups + power.task_platform_idle_wakeups
            : 0

        var vm = task_vm_info_data_t()
        var vmCount = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let vmResult = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &vmCount)
            }
        }
        let footprint: UInt64 = vmResult == KERN_SUCCESS ? vm.phys_footprint : 0

        let uptime = max(ProcessInfo.processInfo.systemUptime - launchUptime, 1)
        return CostSample(cpuSeconds: cpu, wakeups: wakeups, footprintBytes: footprint, uptime: uptime)
    }

    private static func seconds(_ time: timeval) -> Double {
        Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000
    }
}

/// The panel footer's "receipt": what Sill has cost you since launch.
public struct CostReceipt: Equatable, Sendable {
    public let cpuPercent: Double
    public let wakeupsPerHour: Double
    public let footprintMB: Double

    public init(sample: CostSample) {
        let uptime = max(sample.uptime, 1)
        cpuPercent = sample.cpuSeconds / uptime * 100
        wakeupsPerHour = Double(sample.wakeups) / uptime * 3600
        footprintMB = Double(sample.footprintBytes) / 1_048_576
    }

    private static let posix = Locale(identifier: "en_US_POSIX")

    public var cpuText: String {
        let format = cpuPercent < 1 ? "%.3f%%" : "%.1f%%"
        return String(format: format, locale: Self.posix, cpuPercent)
    }

    public var wakeupsText: String {
        String(format: "%.0f", locale: Self.posix, wakeupsPerHour)
    }

    public var memoryText: String {
        String(format: "%.0f MB", locale: Self.posix, footprintMB)
    }

    /// e.g. "0.004% CPU · 41 wakeups/h · 36 MB"
    public var summary: String {
        String(
            localized: "\(cpuText) CPU · \(wakeupsText) wakeups/h · \(memoryText)",
            comment: "Cost receipt footer: CPU percent, wakeups per hour, memory"
        )
    }
}
