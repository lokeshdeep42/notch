import AppKit
import NotchCore
import Services

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private let hub = NotchHub()
    private var manager: NotchWindowManager?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CostSample.markLaunch()
        Log.app.info("\(Branding.appName, privacy: .public) \(Branding.version, privacy: .public) launched")

        statusItem = StatusItemController(preferences: preferences, openSettings: {})

        let manager = NotchWindowManager(hub: hub, preferences: preferences)
        manager.start()
        self.manager = manager
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager?.stop()
        hub.deactivateAll()
    }
}
