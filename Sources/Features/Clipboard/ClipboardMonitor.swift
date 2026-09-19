import AppKit
import Services

/// What changed on the pasteboard, already filtered and extracted.
struct ClipCapture {
    var kind: ClipEntry.Kind
    var text: String?
    var fileURLs: [URL] = []
    var imageData: Data?
    var sourceAppName: String?
    var sourceBundleID: String?
}

/// The one repeating timer in the app, listed in docs/01-ARCHITECTURE.md §Performance.
///
/// macOS has no pasteboard-change notification, so this reads `NSPasteboard.changeCount` — a
/// single integer — once a second, and only reads contents when it changed. It is:
/// - off unless the user turns clipboard history on,
/// - stopped while paused, while the screens sleep, while the screen is locked and during fast
///   user switching,
/// - slowed to every 10 s once the user has been idle for 5 minutes,
/// - coalesced by the system (0.5 s tolerance).
@MainActor
final class ClipboardMonitor {
    var onCapture: ((ClipCapture) -> Void)?
    var blocklist: () -> Set<String> = { [] }

    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount = 0
    private var wanted = false
    private var suspended = false
    private var slowMode = false
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    static let activeInterval: TimeInterval = 1.0
    static let idleInterval: TimeInterval = 10.0
    static let idleThreshold: TimeInterval = 300

    var isRunning: Bool { timer != nil }

    func start() {
        guard !wanted else { return }
        wanted = true
        lastChangeCount = pasteboard.changeCount
        observeSystem()
        reschedule()
        Log.clipboard.info("Clipboard capture on")
    }

    func stop() {
        wanted = false
        invalidateTimer()
        for (center, token) in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
        Log.clipboard.info("Clipboard capture off")
    }

    /// Call after writing to the pasteboard ourselves, so our own copy isn't recorded again.
    func ignoreCurrentContents() {
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: Timer

    private func reschedule() {
        invalidateTimer()
        guard wanted, !suspended else { return }
        let interval = slowMode ? Self.idleInterval : Self.activeInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = interval * 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let idle = Self.secondsSinceLastInput()
        let shouldBeSlow = idle > Self.idleThreshold
        if shouldBeSlow != slowMode {
            slowMode = shouldBeSlow
            reschedule()
        }

        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        capture()
    }

    private static func secondsSinceLastInput() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    // MARK: Capture

    private func capture() {
        let types = (pasteboard.types ?? []).map(\.rawValue)
        let source = NSWorkspace.shared.frontmostApplication
        guard ClipboardFilter.shouldCapture(types: types, sourceBundleID: source?.bundleIdentifier,
                                            blocklist: blocklist()) else {
            Log.clipboard.debug("Skipped a pasteboard change (concealed, transient or blocklisted)")
            return
        }

        var result: ClipCapture?
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            result = ClipCapture(kind: .files, fileURLs: urls)
        } else if let png = pasteboard.data(forType: .png) {
            result = ClipCapture(kind: .image, imageData: png)
        } else if let tiff = pasteboard.data(forType: .tiff),
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            result = ClipCapture(kind: .image, imageData: png)
        } else if let string = pasteboard.string(forType: .string),
                  !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = ClipCapture(kind: .text, text: string)
        }

        guard var capture = result else { return }
        capture.sourceAppName = source?.localizedName
        capture.sourceBundleID = source?.bundleIdentifier
        onCapture?(capture)
    }

    // MARK: Suspension

    private func observeSystem() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        observe(workspace, NSWorkspace.screensDidSleepNotification, suspend: true)
        observe(workspace, NSWorkspace.screensDidWakeNotification, suspend: false)
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification, suspend: true)
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification, suspend: false)
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), suspend: true)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), suspend: false)
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, suspend: Bool) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.suspended = suspend
                if !suspend {
                    // Anything copied while we slept is still worth keeping.
                    self.slowMode = false
                }
                self.reschedule()
            }
        }
        observers.append((center, token))
    }
}
