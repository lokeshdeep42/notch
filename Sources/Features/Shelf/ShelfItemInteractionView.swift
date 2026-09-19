import AppKit
import SwiftUI

/// AppKit layer over each shelf tile. SwiftUI's `.draggable` can't produce real files for other
/// apps from a non-activating panel, so clicks, double-clicks, drag-out and the context menu all
/// live here.
///
/// Drag-out writes the stored file URL with a `.copy`-only operation mask: Finder, Mail, Slack and
/// browser upload fields all accept file URLs, and the shelf keeps its own copy. (The spec called
/// for `NSFilePromiseProvider`; see docs/ADR.md for why URLs won.)
struct ShelfItemInteraction: NSViewRepresentable {
    let onClick: (NSEvent.ModifierFlags) -> Void
    let onDoubleClick: () -> Void
    let dragPayload: () -> [(url: URL, image: NSImage)]
    let menu: () -> NSMenu

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        update(view)
        return view
    }

    func updateNSView(_ view: InteractionView, context: Context) {
        update(view)
    }

    private func update(_ view: InteractionView) {
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        view.dragPayload = dragPayload
        view.menuProvider = menu
    }

    final class InteractionView: NSView, NSDraggingSource {
        var onClick: (NSEvent.ModifierFlags) -> Void = { _ in }
        var onDoubleClick: () -> Void = {}
        var dragPayload: () -> [(url: URL, image: NSImage)] = { [] }
        var menuProvider: () -> NSMenu = { NSMenu() }

        private var mouseDownEvent: NSEvent?
        private var didDrag = false

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            didDrag = false
            if event.clickCount == 2 {
                onDoubleClick()
            } else {
                onClick(event.modifierFlags)
            }
        }

        override func mouseDragged(with event: NSEvent) {
            guard !didDrag, let start = mouseDownEvent else { return }
            let dx = event.locationInWindow.x - start.locationInWindow.x
            let dy = event.locationInWindow.y - start.locationInWindow.y
            // Small hysteresis so a slightly shaky click doesn't start a drag.
            guard dx * dx + dy * dy > 16 else { return }
            didDrag = true

            let payload = dragPayload()
            guard !payload.isEmpty else { return }
            let items: [NSDraggingItem] = payload.enumerated().map { index, entry in
                let item = NSDraggingItem(pasteboardWriter: entry.url as NSURL)
                let offset = CGFloat(index) * 6
                item.setDraggingFrame(bounds.offsetBy(dx: offset, dy: -offset), contents: entry.image)
                return item
            }
            let session = beginDraggingSession(with: items, event: start, source: self)
            session.animatesToStartingPositionsOnCancelOrFail = true
            session.draggingFormation = .pile
        }

        override func mouseUp(with event: NSEvent) {
            mouseDownEvent = nil
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            menuProvider()
        }

        func draggingSession(_ session: NSDraggingSession,
                             sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            // Copy only: dropping on Finder in the same volume must not *move* the shelf's file.
            .copy
        }
    }
}

/// `NSMenuItem` that runs a closure, so menus can be built inline.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, symbol: String? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        if let symbol {
            image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        self.handler = {}
        super.init(coder: coder)
    }

    @objc private func fire() {
        handler()
    }
}
