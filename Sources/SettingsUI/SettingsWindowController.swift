import AppKit
import Services
import SwiftUI

/// The preferences window. An agent app has no main menu, so this is a plain AppKit window hosting
/// SwiftUI, brought to the front explicitly.
@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let preferences: Preferences
    private let launchAtLogin: LaunchAtLogin
    private let permissions: PermissionService
    private var window: NSWindow?

    public init(preferences: Preferences, launchAtLogin: LaunchAtLogin, permissions: PermissionService) {
        self.preferences = preferences
        self.launchAtLogin = launchAtLogin
        self.permissions = permissions
    }

    public func show(tab: SettingsTab = .general) {
        launchAtLogin.refresh()
        permissions.refresh()
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView(
            preferences: preferences, launchAtLogin: launchAtLogin, permissions: permissions, initialTab: tab
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "\(Branding.appName) Settings", comment: "Settings window title")
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        // Drop the SwiftUI tree so a closed settings window costs nothing.
        window?.contentView = nil
        window = nil
    }
}

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general, hover, modules, advanced, about
    public var id: String { rawValue }
}
