import Foundation
import IOKit
import IOKit.ps
import Services

struct PowerSnapshot: Equatable {
    var percent: Int
    var isCharging: Bool
    var isOnAC: Bool
    var isCharged: Bool
    /// Minutes, nil while macOS is still estimating.
    var minutesToEmpty: Int?
    var minutesToFull: Int?

    var symbolName: String {
        if isCharging || (isOnAC && isCharged) { return "battery.100percent.bolt" }
        switch percent {
        case 88...: return "battery.100percent"
        case 63..<88: return "battery.75percent"
        case 38..<63: return "battery.50percent"
        case 13..<38: return "battery.25percent"
        default: return "battery.0percent"
        }
    }
}

struct BatteryHealth: Equatable {
    var cycleCount: Int?
    var healthPercent: Int?
}

/// Battery state from IOKit's power-source notification — a run-loop source that fires only when
/// something changes. No timer, no polling.
@MainActor
final class PowerMonitor: ObservableObject {
    @Published private(set) var snapshot: PowerSnapshot?
    @Published private(set) var health: BatteryHealth?

    /// Called when the charger is connected or disconnected (not on percentage changes).
    var onPowerSourceChange: ((PowerSnapshot) -> Void)?

    private var runLoopSource: CFRunLoopSource?

    nonisolated static var hasBattery: Bool { read() != nil }

    func start() {
        guard runLoopSource == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }, context)?.takeRetainedValue() else {
            Log.power.error("Could not create power-source notification")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
        refresh(initial: true)
        Log.power.info("Power monitor started")
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        runLoopSource = nil
    }

    func refresh(initial: Bool = false) {
        let previous = snapshot
        let current = Self.read()
        snapshot = current
        if !initial, let previous, let current, previous.isOnAC != current.isOnAC {
            onPowerSourceChange?(current)
        }
    }

    /// Cycle count and health change slowly; read them only when the panel opens.
    func refreshHealth() {
        health = Self.readHealth()
    }

    // MARK: IOKit

    nonisolated static func read() -> PowerSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
                    as? [String: Any],
                  description["Type"] as? String == "InternalBattery"
            else { continue }

            let current = description["Current Capacity"] as? Int ?? 0
            let maximum = description["Max Capacity"] as? Int ?? 100
            let percent = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : current
            let toEmpty = description["Time to Empty"] as? Int
            let toFull = description["Time to Full Charge"] as? Int
            return PowerSnapshot(
                percent: min(max(percent, 0), 100),
                isCharging: description["Is Charging"] as? Bool ?? false,
                isOnAC: description["Power Source State"] as? String == "AC Power",
                isCharged: description["Is Charged"] as? Bool ?? false,
                minutesToEmpty: (toEmpty ?? -1) > 0 ? toEmpty : nil,
                minutesToFull: (toFull ?? -1) > 0 ? toFull : nil
            )
        }
        return nil
    }

    nonisolated static func readHealth() -> BatteryHealth? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        func integer(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
        }

        let design = integer("DesignCapacity")
        // Apple silicon reports the true maximum as AppleRawMaxCapacity; MaxCapacity is a percentage.
        let maximum = integer("AppleRawMaxCapacity") ?? integer("NominalChargeCapacity")
        var healthPercent: Int?
        if let design, let maximum, design > 0 {
            healthPercent = min(Int((Double(maximum) / Double(design) * 100).rounded()), 100)
        }
        return BatteryHealth(cycleCount: integer("CycleCount"), healthPercent: healthPercent)
    }
}
