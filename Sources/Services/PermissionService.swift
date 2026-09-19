import AppKit
import ApplicationServices

/// Live permission status. Never cached across wake or app activation — the "it keeps asking even
/// though I granted it" bug comes from trusting a stale answer.
///
/// v1 only ever uses Automation (Apple Events), and only for Music/Spotify controls when the
/// Now Playing helper is unavailable. Nothing here ever *requests* a permission; requests happen at
/// the moment of use, after an in-app explanation.
@MainActor
public final class PermissionService: ObservableObject {
    public enum AutomationStatus: Equatable {
        case granted
        case denied
        case notAsked
        case appNotRunning
        case unknown
    }

    public struct Target: Identifiable, Equatable {
        public let bundleID: String
        public let name: String
        public var id: String { bundleID }
    }

    public static let automationTargets = [
        Target(bundleID: "com.apple.Music", name: "Music"),
        Target(bundleID: "com.spotify.client", name: "Spotify"),
    ]

    @Published public private(set) var automation: [String: AutomationStatus] = [:]

    private var observers: [NSObjectProtocol] = []

    public init() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }

    /// Checks without prompting. The check can block briefly, so it runs off the main actor.
    public func refresh() {
        for target in Self.automationTargets {
            let bundleID = target.bundleID
            Task.detached(priority: .utility) {
                let status = Self.checkAutomation(bundleID: bundleID)
                await MainActor.run { [weak self] in
                    self?.automation[bundleID] = status
                }
            }
        }
    }

    nonisolated static func checkAutomation(bundleID: String) -> AutomationStatus {
        let descriptor = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let address = descriptor.aeDesc else { return .unknown }
        let result = AEDeterminePermissionToAutomateTarget(address, typeWildCard, typeWildCard, false)
        switch result {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .notAsked
        case OSStatus(procNotFound): return .appNotRunning
        default: return .unknown
        }
    }

    public static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
