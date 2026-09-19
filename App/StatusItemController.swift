import AppKit
import Services

/// The menu bar item: the one place a user can always find Settings, Pause and Quit.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let preferences: Preferences
    private let openSettings: () -> Void
    private let pauseItem: NSMenuItem

    init(preferences: Preferences, openSettings: @escaping () -> Void) {
        self.preferences = preferences
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        pauseItem = NSMenuItem(title: "", action: #selector(togglePause), keyEquivalent: "")
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.topthird.inset.filled",
                accessibilityDescription: Branding.appName
            )
            button.image?.isTemplate = true
            button.toolTip = Branding.appName
        }

        let menu = NSMenu()
        menu.delegate = self

        let settings = NSMenuItem(
            title: String(localized: "Settings…", comment: "Status menu item"),
            action: #selector(showSettings), keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: String(localized: "Quit \(Branding.appName)", comment: "Status menu item"),
            action: #selector(quit), keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        updatePauseTitle()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updatePauseTitle()
    }

    private func updatePauseTitle() {
        pauseItem.title = preferences.isPaused
            ? String(localized: "Resume \(Branding.appName)", comment: "Status menu item")
            : String(localized: "Pause \(Branding.appName)", comment: "Status menu item")
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func togglePause() {
        preferences.isPaused.toggle()
        updatePauseTitle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
