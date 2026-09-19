import AppKit
import Services

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CostSample.markLaunch()
        Log.app.info("\(Branding.appName, privacy: .public) \(Branding.version, privacy: .public) launched")
        statusItem = StatusItemController(preferences: preferences, openSettings: {})
    }
}
