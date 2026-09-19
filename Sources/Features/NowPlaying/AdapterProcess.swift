import Foundation
import Services

/// Runs the bundled `mediaremote-adapter` (BSD-3-Clause) under `/usr/bin/perl`, which is
/// Apple-signed and therefore still answered by `mediaremoted` after macOS 15.4.
/// See `docs/02-TECHNICAL-REFERENCE.md` §6.
///
/// The stream process blocks on MediaRemote notifications; it does not poll.
final class AdapterProcess {
    struct Location {
        let script: URL
        let framework: URL
    }

    /// The helper ships inside the app bundle: script in Resources, framework in Frameworks.
    static func locate(in bundle: Bundle = .main) -> Location? {
        guard let resources = bundle.resourceURL, let frameworks = bundle.privateFrameworksURL else { return nil }
        let script = resources.appendingPathComponent("mediaremote-adapter.pl")
        let framework = frameworks.appendingPathComponent("MediaRemoteAdapter.framework")
        let fm = FileManager.default
        guard fm.fileExists(atPath: script.path), fm.fileExists(atPath: framework.path) else { return nil }
        return Location(script: script, framework: framework)
    }

    private static let perl = URL(fileURLWithPath: "/usr/bin/perl")

    private let location: Location
    private var process: Process?
    private var readTask: Task<Void, Never>?
    private(set) var startedAt: Date?

    init(location: Location) {
        self.location = location
    }

    var isRunning: Bool { process?.isRunning ?? false }

    /// Starts `stream`. Lines and exit are delivered on the main actor.
    func start(
        onLine: @escaping @MainActor (String) -> Void,
        onExit: @escaping @MainActor (Int32) -> Void
    ) throws {
        stop()
        let process = Process()
        process.executableURL = Self.perl
        process.arguments = [location.script.path, location.framework.path, "stream", "--micros", "--debounce=100"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { finished in
            let status = finished.terminationStatus
            Task { @MainActor in onExit(status) }
        }
        try process.run()
        self.process = process
        startedAt = Date()
        Log.media.info("Adapter stream started (pid \(process.processIdentifier, privacy: .public))")

        let handle = output.fileHandleForReading
        readTask = Task.detached(priority: .utility) {
            do {
                for try await line in handle.bytes.lines {
                    await MainActor.run { onLine(line) }
                }
            } catch {
                Log.media.error("Adapter stream read failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Terminates the helper. A stray helper process is exactly what shows up in battery reports.
    func stop() {
        readTask?.cancel()
        readTask = nil
        if let process, process.isRunning {
            process.terminationHandler = nil
            process.terminate()
            Log.media.info("Adapter stream stopped")
        }
        process = nil
        startedAt = nil
    }

    // MARK: Commands

    enum Command: Int {
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
    }

    /// Fire-and-forget one-shot helper invocation.
    func send(_ command: Command) {
        runOnce(["send", String(command.rawValue)])
    }

    func seek(to seconds: TimeInterval) {
        let micros = Int64(max(seconds, 0) * 1_000_000)
        runOnce(["seek", String(micros)])
    }

    private func runOnce(_ arguments: [String]) {
        let process = Process()
        process.executableURL = Self.perl
        process.arguments = [location.script.path, location.framework.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { finished in
            if finished.terminationStatus != 0 {
                Log.media.error("Adapter command \(arguments.joined(separator: " "), privacy: .public) exited \(finished.terminationStatus, privacy: .public)")
            }
        }
        do {
            try process.run()
        } catch {
            Log.media.error("Adapter command failed to launch: \(error.localizedDescription, privacy: .public)")
        }
    }
}
