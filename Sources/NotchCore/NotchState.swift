import Foundation

/// What a single display's panel is doing. See `docs/01-ARCHITECTURE.md` §state machine.
public enum NotchPhase: Equatable, Sendable {
    /// Nothing but the hardware notch (and static wings, if a module shows live activity).
    case closed
    /// The pointer is in the hover zone; waiting for the enter delay or a confirmed intent.
    case pending
    case open
    /// The pointer has left; waiting for the exit delay. Re-entering cancels it.
    case closing
    /// A brief, self-dismissing notification (track change, charger). Never interrupts `open`.
    case peek
    /// A fullscreen app owns the display, the session is locked, or the user paused the app.
    case suppressed

    public var isExpanded: Bool { self == .open || self == .closing }
}

public enum NotchEvent: Equatable, Sendable {
    case pointerEntered
    case pointerExited
    case enterDelayElapsed
    case exitDelayElapsed
    /// `HoverIntent` saw the pointer settle inside the zone — open without waiting out the delay.
    case intentConfirmed
    /// `HoverIntent` saw the pointer racing upward (toward the menu bar) — restart the delay.
    case intentRestart
    case clicked
    /// A file drag came close enough to the notch to pull it open.
    case dragApproached
    case dragEnded
    case peekRequested
    case peekElapsed
    /// Explicit close: Escape, or an action like "copy from clipboard history" finished.
    case collapseRequested
    case suppress
    case unsuppress
}

/// Side effects the controller performs. Timers are one-shot and cancellable; there is no
/// repeating timer anywhere in the state machine.
public enum NotchEffect: Equatable, Sendable {
    case scheduleEnter
    case scheduleExit
    case schedulePeekEnd
    case cancelTimers
}

/// A small, total state machine. Every (phase, event) pair has an explicit answer, which is what
/// keeps hover behaviour predictable — ad-hoc booleans are how this category gets flicker.
public struct NotchStateMachine: Equatable, Sendable {
    public private(set) var phase: NotchPhase
    public private(set) var isPointerInside: Bool
    /// True while a file drag is holding the panel open.
    public private(set) var isDragging: Bool

    public init(phase: NotchPhase = .closed) {
        self.phase = phase
        self.isPointerInside = false
        self.isDragging = false
    }

    @discardableResult
    public mutating func send(_ event: NotchEvent) -> [NotchEffect] {
        // Pointer tracking is recorded in every phase so that leaving suppression starts from truth.
        switch event {
        case .pointerEntered: isPointerInside = true
        case .pointerExited: isPointerInside = false
        default: break
        }

        if phase == .suppressed {
            guard event == .unsuppress else { return [] }
            phase = .closed
            isDragging = false
            return []
        }

        switch (phase, event) {
        case (_, .suppress):
            phase = .suppressed
            isDragging = false
            return [.cancelTimers]

        case (_, .unsuppress):
            return []

        case (_, .collapseRequested):
            phase = .closed
            isDragging = false
            return [.cancelTimers]

        // MARK: Drag always wins — the shelf's signature interaction.
        case (.closed, .dragApproached), (.pending, .dragApproached),
             (.closing, .dragApproached), (.peek, .dragApproached):
            phase = .open
            isDragging = true
            return [.cancelTimers]
        case (.open, .dragApproached):
            isDragging = true
            return []
        case (_, .dragEnded):
            let wasDragging = isDragging
            isDragging = false
            guard wasDragging, phase == .open, !isPointerInside else { return [] }
            phase = .closing
            return [.scheduleExit]

        // MARK: closed
        case (.closed, .pointerEntered):
            phase = .pending
            return [.cancelTimers, .scheduleEnter]
        case (.closed, .clicked):
            phase = .open
            return [.cancelTimers]
        case (.closed, .peekRequested):
            phase = .peek
            return [.schedulePeekEnd]

        // MARK: pending
        case (.pending, .enterDelayElapsed), (.pending, .intentConfirmed), (.pending, .clicked):
            phase = .open
            return [.cancelTimers]
        case (.pending, .intentRestart):
            return [.cancelTimers, .scheduleEnter]
        case (.pending, .pointerExited):
            phase = .closed
            return [.cancelTimers]

        // MARK: open
        case (.open, .pointerExited):
            guard !isDragging else { return [] }
            phase = .closing
            return [.scheduleExit]

        // MARK: closing
        case (.closing, .pointerEntered), (.closing, .clicked):
            phase = .open
            return [.cancelTimers]
        case (.closing, .exitDelayElapsed):
            phase = .closed
            return []

        // MARK: peek
        case (.peek, .peekElapsed):
            phase = isPointerInside ? .pending : .closed
            return isPointerInside ? [.cancelTimers, .scheduleEnter] : []
        case (.peek, .pointerEntered):
            phase = .pending
            return [.cancelTimers, .scheduleEnter]
        case (.peek, .clicked):
            phase = .open
            return [.cancelTimers]
        case (.peek, .peekRequested):
            return [.schedulePeekEnd]

        // Everything else is a deliberate no-op: stale timers, peeks while open, duplicate events.
        default:
            return []
        }
    }
}
