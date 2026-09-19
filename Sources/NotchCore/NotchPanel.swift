import AppKit
import SwiftUI

/// Borderless, non-activating panel that sits over the notch. See `docs/02-TECHNICAL-REFERENCE.md` §3.
/// Its frame is set once (maximum expanded size) and never animated.
@MainActor
final class NotchPanel: NSPanel {
    /// Only true while a module that needs typing (clipboard search) is showing.
    var allowsKey = false
    var onCancel: (() -> Void)?

    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // ⚠ VERIFY on hardware: .statusBar vs mainMenu+3 stacking (ADR open question).
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        animationBehavior = .none
        applyCollectionBehavior()
    }

    func applyCollectionBehavior() {
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    /// macOS can silently drop `.canJoinAllSpaces` on re-order, so re-assert it on every reveal.
    override func orderFront(_ sender: Any?) {
        applyCollectionBehavior()
        super.orderFront(sender)
    }

    override func orderFrontRegardless() {
        applyCollectionBehavior()
        super.orderFrontRegardless()
    }

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    /// Escape.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// The panel sits over the menu bar; never let AppKit push it below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Clicks on a non-key, non-activating panel must work on the first click.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
