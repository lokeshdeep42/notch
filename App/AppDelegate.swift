import AppKit
import Combine
import Dispatch
import FeatureClipboard
import FeatureNowPlaying
import FeaturePower
import FeatureShelf
import NotchCore
import Services
import SettingsUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private let hub = NotchHub()
    private let launchAtLogin = LaunchAtLogin()
    private let permissions = PermissionService()
    private var manager: NotchWindowManager?
    private var statusItem: StatusItemController?
    private var settings: SettingsWindowController?
    private var onboarding: OnboardingWindowController?
    private var cancellables: Set<AnyCancellable> = []
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        CostSample.markLaunch()
        installSignalHandlers()
        Log.app.info("\(Branding.appName, privacy: .public) \(Branding.version, privacy: .public) launched")

        let settings = SettingsWindowController(
            preferences: preferences, launchAtLogin: launchAtLogin, permissions: permissions
        )
        self.settings = settings
        statusItem = StatusItemController(preferences: preferences) { settings.show() }
        hub.openSettings = { settings.show() }

        hub.register(NowPlayingModule(preferences: preferences))
        hub.register(ShelfModule(preferences: preferences))
        hub.register(ClipboardModule(preferences: preferences))
        hub.register(PowerModule(preferences: preferences))

        // Module switches take effect immediately and fully unload what they turn off.
        preferences.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.hub.refreshModules() }
            }
            .store(in: &cancellables)

        let manager = NotchWindowManager(hub: hub, preferences: preferences)
        manager.start()
        self.manager = manager

        if !preferences.hasCompletedOnboarding {
            let onboarding = OnboardingWindowController(preferences: preferences)
            self.onboarding = onboarding
            onboarding.show()
        }
    }

    /// Quit cleanly on SIGTERM and SIGINT — logout, restart, `killall`, and Ctrl-C from
    /// `Scripts/run.sh`. The default disposition kills the process outright, which skips
    /// `applicationWillTerminate` and orphans the Now Playing helper: a stray `perl` process in the
    /// user's battery report is precisely what this product exists to avoid. Found by
    /// `Scripts/smoke.sh` on CI.
    ///
    /// A dispatch signal source is event-driven and costs nothing while idle: no timer, no poll.
    private func installSignalHandlers() {
        for number in [SIGTERM, SIGINT] {
            // The source only receives the signal if the default disposition is disarmed first.
            _ = signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler {
                MainActor.assumeIsolated {
                    Log.app.info("Signal \(number, privacy: .public) received; terminating")
                    NSApp.terminate(nil)
                }
            }
            source.resume()
            signalSources.append(source)
        }
    }

    /// Opening the app again from Finder or Spotlight shows Settings — the expected escape hatch
    /// for an app with no Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings?.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager?.stop()
        hub.deactivateAll()
    }
}
