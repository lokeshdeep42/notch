import AppKit
import Services
import SwiftUI

/// First-run experience: three pages at most, skippable at every step (M7-T4).
@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let preferences: Preferences
    private var window: NSWindow?

    public init(preferences: Preferences) {
        self.preferences = preferences
    }

    public func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = OnboardingView(preferences: preferences) { [weak self] in
            self?.finish()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        preferences.hasCompletedOnboarding = true
        window?.close()
    }

    public func windowWillClose(_ notification: Notification) {
        // Closing the window counts as "skip" — never nag again.
        preferences.hasCompletedOnboarding = true
        window?.contentView = nil
        window = nil
    }
}
