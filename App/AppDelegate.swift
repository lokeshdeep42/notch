import AppKit
import Combine
import FeatureNowPlaying
import FeatureShelf
import NotchCore
import Services

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private let hub = NotchHub()
    private var manager: NotchWindowManager?
    private var statusItem: StatusItemController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        CostSample.markLaunch()
        Log.app.info("\(Branding.appName, privacy: .public) \(Branding.version, privacy: .public) launched")

        statusItem = StatusItemController(preferences: preferences, openSettings: {})

        hub.register(NowPlayingModule(preferences: preferences))
        hub.register(ShelfModule(preferences: preferences))

        // Module switches take effect immediately and fully unload what they turn off.
        preferences.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.hub.refreshModules() }
            }
            .store(in: &cancellables)

        let manager = NotchWindowManager(hub: hub, preferences: preferences)
        manager.start()
        self.manager = manager
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager?.stop()
        hub.deactivateAll()
    }
}
