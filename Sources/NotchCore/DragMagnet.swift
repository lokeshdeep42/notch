import AppKit
import Services

/// Notices a file being dragged toward the top of the screen so the notch can lean toward it and
/// open into the shelf before the pointer even arrives.
///
/// Cost model: global monitors for `leftMouseDown`, `leftMouseDragged` and `leftMouseUp`. These need
/// no permission (only keyboard monitors do) and deliver **nothing** while the mouse is idle or
/// merely moving; they fire only during a click or a drag. Whether a drag carries files is decided
/// once per drag from the drag pasteboard's `changeCount`, not per event.
@MainActor
public final class DragMagnet {
    public static let shared = DragMagnet()

    /// Screen-space location of an in-flight file drag.
    var onFileDrag: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?

    private var monitors: [Any] = []
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var changeCountAtMouseDown = 0
    private var classifiedChangeCount = -1
    private var classifiedAsFileDrag = false
    private var isDragging = false

    private init() {}

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard monitors.isEmpty else { return }
        changeCountAtMouseDown = dragPasteboard.changeCount
        let down = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseDown() }
        }
        let dragged = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseDragged() }
        }
        let up = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseUp() }
        }
        monitors = [down, dragged, up].compactMap { $0 }
        Log.notch.debug("DragMagnet started")
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        isDragging = false
        Log.notch.debug("DragMagnet stopped")
    }

    /// True while the left button is down and the drag pasteboard holds something the shelf can
    /// take (files, file promises, images). Plain text drags — selecting and dragging words — don't
    /// count, or the notch would twitch every time someone rearranges a sentence.
    var isFileDragActive: Bool {
        guard NSEvent.pressedMouseButtons & 1 != 0 else { return false }
        let count = dragPasteboard.changeCount
        guard count != changeCountAtMouseDown else { return false }
        if count != classifiedChangeCount {
            classifiedChangeCount = count
            classifiedAsFileDrag = Self.carriesFiles(dragPasteboard)
        }
        return classifiedAsFileDrag
    }

    static func carriesFiles(_ pasteboard: NSPasteboard) -> Bool {
        let types = Set(pasteboard.types ?? [])
        let accepted: Set<NSPasteboard.PasteboardType> = Set(
            [.fileURL, .png, .tiff]
                + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        )
        return !types.isDisjoint(with: accepted)
    }

    private func mouseDown() {
        changeCountAtMouseDown = dragPasteboard.changeCount
        isDragging = false
    }

    private func mouseDragged() {
        guard isFileDragActive else { return }
        isDragging = true
        onFileDrag?(NSEvent.mouseLocation)
    }

    private func mouseUp() {
        guard isDragging else { return }
        isDragging = false
        onDragEnded?()
    }
}
