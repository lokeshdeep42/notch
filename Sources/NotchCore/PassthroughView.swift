import AppKit

@MainActor
protocol PassthroughViewDelegate: AnyObject {
    func pointerEntered()
    func pointerExited()
    func pointerMoved(screenPoint: CGPoint, time: TimeInterval)
    func fileDragEntered()
    func fileDragExited()
    func performDrop(_ pasteboard: NSPasteboard) -> Bool
    /// True while a file-like drag is in flight (see `DragMagnet`).
    var isFileDragActive: Bool { get }
}

/// The panel's content view. The window is wide and transparent, so this view decides which clicks
/// it keeps: anything outside `activeRect` returns nil from `hitTest` and falls through to the app
/// underneath. Getting this wrong makes the app silently eat clicks across the top of the screen.
///
/// It also owns the single tracking area (hover) and acts as the drag destination for the whole
/// panel, so file drops never depend on SwiftUI's drop handling inside a non-activating panel.
@MainActor
final class PassthroughView: NSView {
    weak var delegate: PassthroughViewDelegate?

    /// Region (panel space, flipped) that receives clicks.
    var activeRect: CGRect = .zero
    /// Region (panel space, flipped) that counts as hovering.
    var trackingRect: CGRect = .zero {
        didSet {
            if trackingRect != oldValue { rebuildTrackingArea() }
        }
    }
    /// Whether drops are accepted at all (a drop-accepting module is enabled).
    var acceptsDrops = false

    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(Self.dropTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    static let dropTypes: [NSPasteboard.PasteboardType] =
        [.fileURL, .URL, .png, .tiff] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

    // MARK: Hit testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if activeRect.contains(local) {
            // While a file is being dragged, this view (not SwiftUI) is the drop target.
            if acceptsDrops, delegate?.isFileDragActive == true {
                return self
            }
            return super.hitTest(point)
        }
        if acceptsDrops, trackingRect.contains(local), delegate?.isFileDragActive == true {
            return self
        }
        return nil
    }

    // MARK: Tracking

    private func rebuildTrackingArea() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        guard !trackingRect.isEmpty else {
            trackingArea = nil
            return
        }
        let area = NSTrackingArea(
            rect: trackingRect,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    func removeAllTracking() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = nil
    }

    override func mouseEntered(with event: NSEvent) {
        delegate?.pointerEntered()
    }

    override func mouseExited(with event: NSEvent) {
        delegate?.pointerExited()
    }

    override func mouseMoved(with event: NSEvent) {
        delegate?.pointerMoved(screenPoint: NSEvent.mouseLocation, time: event.timestamp)
    }

    // MARK: Dragging destination

    /// Drags that start in our own panel (a shelf item on its way out) must never drop back in.
    private func accepts(_ sender: NSDraggingInfo) -> Bool {
        acceptsDrops && sender.draggingSource == nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard accepts(sender) else { return [] }
        delegate?.fileDragEntered()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        accepts(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        delegate?.fileDragExited()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        accepts(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard accepts(sender) else { return false }
        return delegate?.performDrop(sender.draggingPasteboard) ?? false
    }
}
