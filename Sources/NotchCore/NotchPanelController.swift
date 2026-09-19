import AppKit
import Combine
import DesignSystem
import Services
import SwiftUI

/// Owns one panel on one display: the window, the state machine, hover intent and the one-shot
/// timers the state machine asks for. Created and destroyed by `NotchWindowManager`; never moved
/// between screens.
@MainActor
final class NotchPanelController: PassthroughViewDelegate {
    let displayID: CGDirectDisplayID
    private(set) var geometry: NotchGeometry

    private let hub: NotchHub
    private let preferences: Preferences
    private let magnet: DragMagnet
    private let panel: NotchPanel
    private let container: PassthroughView
    private let model: PanelModel

    private var machine = NotchStateMachine()
    private var intent = HoverIntent()
    /// The single pending one-shot timer (enter delay, exit delay or peek end).
    private var timerTask: Task<Void, Never>?
    /// Only exists while a file drag is holding the panel open; see `watchForDragRelease`.
    private var dragWatchTask: Task<Void, Never>?

    /// Magnet pull radius around the notch, in points.
    private static let magnetRadius: CGFloat = 150
    /// Pull strength at which the panel snaps open into the shelf.
    private static let magnetSnap: CGFloat = 0.82

    init(displayID: CGDirectDisplayID, geometry: NotchGeometry, hub: NotchHub,
         preferences: Preferences, magnet: DragMagnet) {
        self.displayID = displayID
        self.geometry = geometry
        self.hub = hub
        self.preferences = preferences
        self.magnet = magnet

        let frame = geometry.windowFrame()
        panel = NotchPanel(frame: frame)
        container = PassthroughView(frame: NSRect(origin: .zero, size: frame.size))
        model = PanelModel(displayID: displayID, geometry: geometry)

        let root = NotchRootView(model: model, hub: hub, preferences: preferences)
        let hosting = FirstMouseHostingView(rootView: root)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        // The SwiftUI layout must never try to resize the window.
        hosting.sizingOptions = []
        container.addSubview(hosting)
        panel.contentView = container

        container.delegate = self
        model.onClick = { [weak self] in self?.send(.clicked) }
        model.onCollapse = { [weak self] in self?.send(.collapseRequested) }
        panel.onCancel = { [weak self] in self?.send(.collapseRequested) }

        refreshInteraction()
        Log.display.info("Panel created for display \(displayID, privacy: .public)")
    }

    func show() {
        panel.setFrame(geometry.windowFrame(), display: false)
        panel.orderFrontRegardless()
        syncPointerInside()
    }

    /// Full teardown: no window, no tracking area, no timer. Hidden-but-alive windows are how
    /// notch apps end up burning CPU in fullscreen.
    func tearDown() {
        timerTask?.cancel()
        timerTask = nil
        dragWatchTask?.cancel()
        dragWatchTask = nil
        container.removeAllTracking()
        container.delegate = nil
        panel.orderOut(nil)
        panel.close()
        Log.display.info("Panel torn down for display \(self.displayID, privacy: .public)")
    }

    // MARK: State machine

    func send(_ event: NotchEvent) {
        let previous = machine.phase
        let effects = machine.send(event)
        effects.forEach(perform)
        if machine.phase != previous {
            phaseChanged(from: previous, to: machine.phase)
        }
    }

    private func perform(_ effect: NotchEffect) {
        switch effect {
        case .cancelTimers:
            timerTask?.cancel()
            timerTask = nil
        case .scheduleEnter:
            schedule(.enterDelayElapsed, after: preferences.enterDelay)
        case .scheduleExit:
            schedule(.exitDelayElapsed, after: preferences.exitDelay)
        case .schedulePeekEnd:
            schedule(.peekElapsed, after: model.peek?.duration ?? 2.4)
        }
    }

    /// One-shot, cancellable. Never a repeating timer.
    private func schedule(_ event: NotchEvent, after seconds: Double) {
        timerTask?.cancel()
        let nanoseconds = UInt64(max(seconds, 0) * 1_000_000_000)
        timerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.timerTask = nil
            self?.send(event)
        }
    }

    private func phaseChanged(from old: NotchPhase, to new: NotchPhase) {
        Log.notch.debug("Display \(self.displayID, privacy: .public): \(String(describing: old), privacy: .public) → \(String(describing: new), privacy: .public)")

        let animation: Animation
        switch new {
        case .open: animation = Motion.expand
        case .peek: animation = Motion.peek
        case .pending: animation = Motion.press
        default: animation = Motion.collapse
        }

        if new == .open, !old.isExpanded {
            model.receipt = CostSample.current().map(CostReceipt.init(sample:))
            hub.panelDidOpen()
            intent.reset()
        }

        withAnimation(Motion.resolved(animation)) {
            model.phase = new
            if new != .peek, old == .peek {
                model.peek = nil
            }
            if new.isExpanded || new == .closed {
                model.magnetStrength = 0
                model.magnetLean = 0
            }
        }

        if !new.isExpanded {
            model.isDropTargeted = false
        }
        updateKeyStatus()
        refreshInteraction()
    }

    // MARK: Interaction regions

    /// Recomputes the click and hover regions for the current phase. Call when wings, preferences
    /// or geometry change.
    func refreshInteraction() {
        let deadZone = CGFloat(preferences.deadZone)
        switch machine.phase {
        case .open, .closing:
            let rect = geometry.expandedRect()
            container.activeRect = rect
            container.trackingRect = rect
        case .peek:
            let wing = model.peek?.width ?? 0
            container.activeRect = geometry.collapsedRect(extraWidth: wing)
            container.trackingRect = geometry.hoverRect(deadZone: deadZone, extraWidth: wing)
        case .closed, .pending:
            let wing = hub.wings?.width ?? 0
            container.activeRect = geometry.collapsedRect(extraWidth: wing)
            container.trackingRect = geometry.hoverRect(deadZone: deadZone, extraWidth: wing)
        case .suppressed:
            container.activeRect = .zero
            container.trackingRect = .zero
        }
        container.acceptsDrops = hub.dropModule != nil
    }

    /// A tracking area that changes size under a stationary pointer sends no enter/exit event, so
    /// reconcile against the real pointer position.
    private func syncPointerInside() {
        let point = geometry.panelPoint(fromScreen: NSEvent.mouseLocation)
        let inside = container.trackingRect.contains(point)
        if inside != machine.isPointerInside {
            send(inside ? .pointerEntered : .pointerExited)
        }
    }

    /// The panel only accepts keyboard focus while open on a module that needs typing, and gives
    /// it back as soon as it closes, so keystrokes never vanish into a collapsed notch.
    func updateKeyStatus() {
        let wantsKey = machine.phase == .open && (hub.selectedModule?.wantsKeyboardFocus ?? false)
        panel.allowsKey = wantsKey
        if wantsKey {
            if !panel.isKeyWindow { panel.makeKey() }
        } else if panel.isKeyWindow {
            panel.resignKey()
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }

    // MARK: Peeks and wings

    func showPeek(_ peek: PeekContent) {
        guard machine.phase == .closed || machine.phase == .peek else { return }
        model.peek = peek
        send(.peekRequested)
        refreshInteraction()
    }

    func collapse() {
        send(.collapseRequested)
    }

    // MARK: Magnet

    func handleFileDrag(at screenPoint: CGPoint) {
        guard machine.phase != .suppressed, hub.dropModule != nil else { return }
        guard geometry.screenFrame.insetBy(dx: -1, dy: -1).contains(screenPoint) else {
            releaseMagnet()
            return
        }
        if machine.phase.isExpanded { return }

        let point = geometry.panelPoint(fromScreen: screenPoint)
        let target = geometry.collapsedRect(extraWidth: hub.wings?.width ?? 0)
        let dx = max(target.minX - point.x, 0, point.x - target.maxX)
        let dy = max(point.y - target.maxY, 0)
        let distance = (dx * dx + dy * dy).squareRoot()
        let strength = max(0, 1 - distance / Self.magnetRadius)

        if strength >= Self.magnetSnap {
            hub.selectDropModule()
            send(.dragApproached)
            watchForDragRelease()
            return
        }
        let lean = max(-14, min(14, (point.x - target.midX) * 0.06)) * strength
        model.magnetStrength = strength
        model.magnetLean = lean
        if strength > 0 { watchForDragRelease() }
    }

    func handleDragEnded() {
        dragWatchTask?.cancel()
        dragWatchTask = nil
        releaseMagnet()
        send(.dragEnded)
        syncPointerInside()
    }

    /// Safety net for a drag that opened the panel and then ended somewhere our monitors can't see
    /// (e.g. dropped into another app's window). Checks the mouse button four times a second — only
    /// while such a drag is in flight, never while idle — so the panel can't get stuck open.
    private func watchForDragRelease() {
        guard machine.isDragging || model.magnetStrength > 0, dragWatchTask == nil else { return }
        dragWatchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                if NSEvent.pressedMouseButtons & 1 == 0 {
                    self?.dragWatchTask = nil
                    self?.handleDragEnded()
                    return
                }
            }
        }
    }

    private func releaseMagnet() {
        guard model.magnetStrength != 0 || model.magnetLean != 0 else { return }
        model.magnetStrength = 0
        model.magnetLean = 0
    }

    // MARK: PassthroughViewDelegate

    var isFileDragActive: Bool { magnet.isFileDragActive }

    func pointerEntered() {
        intent.reset()
        send(.pointerEntered)
    }

    func pointerExited() {
        intent.reset()
        send(.pointerExited)
    }

    func pointerMoved(screenPoint: CGPoint, time: TimeInterval) {
        guard machine.phase == .pending, preferences.intentHover else { return }
        switch intent.add(point: screenPoint, time: time) {
        case .confirm:
            Log.hover.debug("Intent confirmed")
            send(.intentConfirmed)
        case .restart:
            Log.hover.debug("Throw toward menu bar — enter delay restarted")
            send(.intentRestart)
        case .none:
            break
        }
    }

    func fileDragEntered() {
        hub.selectDropModule()
        send(.dragApproached)
        model.isDropTargeted = true
    }

    func fileDragExited() {
        model.isDropTargeted = false
        watchForDragRelease()
    }

    func performDrop(_ pasteboard: NSPasteboard) -> Bool {
        dragWatchTask?.cancel()
        dragWatchTask = nil
        model.isDropTargeted = false
        let handled = hub.handleDrop(pasteboard)
        releaseMagnet()
        send(.dragEnded)
        // Tracking areas are silent during a drag session; catch up with where the pointer is.
        syncPointerInside()
        return handled
    }
}
