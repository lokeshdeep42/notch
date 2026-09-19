import AppKit
import Combine
import Services

/// Now Playing with a graceful fallback chain (CLAUDE.md non-negotiable #3):
///   1. the supervised adapter stream (all players, artwork, controls)
///   2. Music/Spotify distributed notifications (no artwork; controls via Apple Events)
///   3. an honest "No media detected" — never a crash, never a spinner.
@MainActor
final class NowPlayingService: ObservableObject {
    enum Source: Equatable {
        case adapter
        case notifications
        case none
    }

    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var artwork: Artwork?
    @Published private(set) var source: Source = .none
    /// Set when the user must be told about the Automation prompt before we trigger it.
    @Published var needsAutomationExplanation = false

    /// Called when a *different* track starts playing (not on pause/resume or position updates).
    var onTrackChange: ((NowPlayingInfo) -> Void)?

    private var decoder = NowPlayingDecoder()
    private var adapter: AdapterProcess?
    private let fallback = DistributedMediaSource()
    private var restartTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var fastFailures = 0
    private var lastArtworkData: Data?
    private var pendingAction: DistributedMediaSource.Action?
    private var isRunning = false

    private static let maxFastFailures = 5
    /// A run shorter than this counts as a crash, not a normal exit.
    private static let fastFailureWindow: TimeInterval = 10
    private static let automationExplainedKey = "AutomationExplained"

    func start() {
        guard !isRunning else { return }
        isRunning = true
        fastFailures = 0
        if let location = AdapterProcess.locate() {
            adapter = AdapterProcess(location: location)
            launchAdapter()
        } else {
            Log.media.notice("Adapter not bundled; using notification fallback")
            startFallback()
        }
    }

    func stop() {
        isRunning = false
        restartTask?.cancel()
        restartTask = nil
        artworkTask?.cancel()
        adapter?.stop()
        adapter = nil
        fallback.stop()
        decoder = NowPlayingDecoder()
        source = .none
        update(nil)
    }

    // MARK: Adapter supervision

    private func launchAdapter() {
        guard isRunning, let adapter else { return }
        do {
            try adapter.start(
                onLine: { [weak self] line in self?.handleAdapterLine(line) },
                onExit: { [weak self] status in self?.adapterExited(status: status) }
            )
            source = .adapter
        } catch {
            Log.media.error("Adapter failed to launch: \(error.localizedDescription, privacy: .public)")
            adapterExited(status: -1)
        }
    }

    private func handleAdapterLine(_ line: String) {
        guard let output = decoder.consume(line: line) else { return }
        switch output {
        case .nothingPlaying:
            update(nil)
        case let .info(info):
            update(info)
        }
    }

    private func adapterExited(status: Int32) {
        guard isRunning else { return }
        let ranFor = adapter?.startedAt.map { Date().timeIntervalSince($0) } ?? 0
        fastFailures = ranFor < Self.fastFailureWindow ? fastFailures + 1 : 1
        Log.media.error("Adapter exited with status \(status, privacy: .public) after \(ranFor, privacy: .public)s (failure \(self.fastFailures, privacy: .public))")

        if fastFailures >= Self.maxFastFailures {
            Log.media.error("Adapter keeps failing; falling back to notifications")
            adapter?.stop()
            adapter = nil
            startFallback()
            return
        }
        // Exponential backoff: 1, 2, 4, 8 s. One-shot, cancellable.
        let delay = pow(2, Double(fastFailures - 1))
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.launchAdapter()
        }
    }

    private func startFallback() {
        source = .notifications
        fallback.onChange = { [weak self] info in self?.update(info) }
        fallback.start()
    }

    // MARK: State

    private func update(_ new: NowPlayingInfo?) {
        let old = info
        info = new

        if let new, new.isPlaying, old?.trackKey != new.trackKey {
            onTrackChange?(new)
        }

        let data = new?.artworkData
        if data != lastArtworkData {
            lastArtworkData = data
            artworkTask?.cancel()
            guard let data else {
                artwork = nil
                return
            }
            artworkTask = Task { @MainActor [weak self] in
                let processed = await ArtworkProcessor.process(data)
                guard !Task.isCancelled else { return }
                self?.artwork = processed
            }
        }
    }

    // MARK: Controls

    var canControl: Bool {
        switch source {
        case .adapter: return info != nil
        case .notifications: return info != nil && fallback.activePlayer != nil
        case .none: return false
        }
    }

    var canSeek: Bool { source == .adapter && info?.duration != nil }

    func togglePlayPause() { control(.togglePlayPause, fallbackAction: .playPause) }
    func next() { control(.nextTrack, fallbackAction: .next) }
    func previous() { control(.previousTrack, fallbackAction: .previous) }

    func seek(to seconds: TimeInterval) {
        guard source == .adapter else { return }
        adapter?.seek(to: seconds)
    }

    private func control(_ command: AdapterProcess.Command, fallbackAction: DistributedMediaSource.Action) {
        switch source {
        case .adapter:
            adapter?.send(command)
        case .notifications:
            // Explain the Automation prompt once, before macOS shows it (CLAUDE.md #4).
            if !UserDefaults.standard.bool(forKey: Self.automationExplainedKey) {
                pendingAction = fallbackAction
                needsAutomationExplanation = true
                return
            }
            fallback.perform(fallbackAction)
        case .none:
            break
        }
    }

    func confirmAutomationExplanation() {
        UserDefaults.standard.set(true, forKey: Self.automationExplainedKey)
        needsAutomationExplanation = false
        if let action = pendingAction {
            pendingAction = nil
            fallback.perform(action)
        }
    }

    func cancelAutomationExplanation() {
        needsAutomationExplanation = false
        pendingAction = nil
    }

    var playerName: String? {
        guard let bundleID = info?.bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
