import AppKit

@main
enum SillMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Agent app: no Dock icon, no main menu. LSUIElement in Info.plist does the same for the
        // bundled app; this line also covers `swift run` during development.
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
