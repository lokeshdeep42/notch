import XCTest
@testable import NotchCore

final class NotchStateTests: XCTestCase {
    private func machine(_ phase: NotchPhase = .closed, pointerInside: Bool = false) -> NotchStateMachine {
        var m = NotchStateMachine()
        switch phase {
        case .closed:
            break
        case .pending:
            m.send(.pointerEntered)
        case .open:
            m.send(.pointerEntered)
            m.send(.enterDelayElapsed)
        case .closing:
            m.send(.pointerEntered)
            m.send(.enterDelayElapsed)
            m.send(.pointerExited)
        case .peek:
            m.send(.peekRequested)
        case .suppressed:
            m.send(.suppress)
        }
        if pointerInside, !m.isPointerInside { m.send(.pointerEntered) }
        XCTAssertEqual(m.phase, phase, "fixture setup")
        return m
    }

    func testClosedPointerEnteredGoesPendingAndSchedulesEnter() {
        var m = machine()
        XCTAssertEqual(m.send(.pointerEntered), [.cancelTimers, .scheduleEnter])
        XCTAssertEqual(m.phase, .pending)
    }

    func testPendingEnterDelayOpens() {
        var m = machine(.pending)
        XCTAssertEqual(m.send(.enterDelayElapsed), [.cancelTimers])
        XCTAssertEqual(m.phase, .open)
    }

    func testPendingIntentConfirmedOpensEarly() {
        var m = machine(.pending)
        XCTAssertEqual(m.send(.intentConfirmed), [.cancelTimers])
        XCTAssertEqual(m.phase, .open)
    }

    func testPendingIntentRestartRestartsDelay() {
        var m = machine(.pending)
        XCTAssertEqual(m.send(.intentRestart), [.cancelTimers, .scheduleEnter])
        XCTAssertEqual(m.phase, .pending)
    }

    func testPendingPointerExitedCloses() {
        var m = machine(.pending)
        XCTAssertEqual(m.send(.pointerExited), [.cancelTimers])
        XCTAssertEqual(m.phase, .closed)
    }

    func testOpenPointerExitedStartsClosing() {
        var m = machine(.open)
        XCTAssertEqual(m.send(.pointerExited), [.scheduleExit])
        XCTAssertEqual(m.phase, .closing)
    }

    func testClosingReenterReopens() {
        var m = machine(.closing)
        XCTAssertEqual(m.send(.pointerEntered), [.cancelTimers])
        XCTAssertEqual(m.phase, .open)
    }

    func testClosingExitDelayCloses() {
        var m = machine(.closing)
        XCTAssertEqual(m.send(.exitDelayElapsed), [])
        XCTAssertEqual(m.phase, .closed)
    }

    func testClosedPeekSchedulesPeekEnd() {
        var m = machine()
        XCTAssertEqual(m.send(.peekRequested), [.schedulePeekEnd])
        XCTAssertEqual(m.phase, .peek)
    }

    func testPeekNeverInterruptsOpen() {
        var m = machine(.open)
        XCTAssertEqual(m.send(.peekRequested), [])
        XCTAssertEqual(m.phase, .open)
    }

    func testPeekElapsedCloses() {
        var m = machine(.peek)
        XCTAssertEqual(m.send(.peekElapsed), [])
        XCTAssertEqual(m.phase, .closed)
    }

    func testPeekElapsedWithPointerInsideGoesPending() {
        var m = machine(.peek)
        m.send(.pointerEntered)
        XCTAssertEqual(m.phase, .pending)
        // Stale peek timer arriving later is ignored.
        XCTAssertEqual(m.send(.peekElapsed), [])
        XCTAssertEqual(m.phase, .pending)
    }

    func testPeekPointerEnteredGoesPending() {
        var m = machine(.peek)
        XCTAssertEqual(m.send(.pointerEntered), [.cancelTimers, .scheduleEnter])
        XCTAssertEqual(m.phase, .pending)
    }

    func testDragApproachOpensFromClosed() {
        var m = machine()
        XCTAssertEqual(m.send(.dragApproached), [.cancelTimers])
        XCTAssertEqual(m.phase, .open)
        XCTAssertTrue(m.isDragging)
    }

    func testDragHoldsPanelOpenWhenPointerLeaves() {
        var m = machine()
        m.send(.dragApproached)
        XCTAssertEqual(m.send(.pointerExited), [])
        XCTAssertEqual(m.phase, .open)
    }

    func testDragEndedOutsideStartsClosing() {
        var m = machine()
        m.send(.dragApproached)
        XCTAssertEqual(m.send(.dragEnded), [.scheduleExit])
        XCTAssertEqual(m.phase, .closing)
        XCTAssertFalse(m.isDragging)
    }

    func testDragEndedInsideStaysOpen() {
        var m = machine()
        m.send(.dragApproached)
        m.send(.pointerEntered)
        XCTAssertEqual(m.send(.dragEnded), [])
        XCTAssertEqual(m.phase, .open)
    }

    func testDragEndedWithoutDragIsNoOp() {
        var m = machine(.open)
        XCTAssertEqual(m.send(.dragEnded), [])
        XCTAssertEqual(m.phase, .open)
    }

    func testSuppressFromEveryPhase() {
        for phase in [NotchPhase.closed, .pending, .open, .closing, .peek] {
            var m = machine(phase)
            XCTAssertEqual(m.send(.suppress), [.cancelTimers], "\(phase)")
            XCTAssertEqual(m.phase, .suppressed, "\(phase)")
        }
    }

    func testSuppressedIgnoresEverythingButUnsuppress() {
        var m = machine(.suppressed)
        let events: [NotchEvent] = [
            .pointerEntered, .enterDelayElapsed, .intentConfirmed, .clicked,
            .dragApproached, .peekRequested, .collapseRequested, .suppress,
        ]
        for event in events {
            XCTAssertEqual(m.send(event), [], "\(event)")
            XCTAssertEqual(m.phase, .suppressed, "\(event)")
        }
        m.send(.unsuppress)
        XCTAssertEqual(m.phase, .closed)
    }

    func testPointerStateTrackedWhileSuppressed() {
        var m = machine(.suppressed)
        m.send(.pointerEntered)
        m.send(.unsuppress)
        XCTAssertTrue(m.isPointerInside)
    }

    func testClickOpensImmediately() {
        var closed = machine()
        XCTAssertEqual(closed.send(.clicked), [.cancelTimers])
        XCTAssertEqual(closed.phase, .open)

        var pending = machine(.pending)
        pending.send(.clicked)
        XCTAssertEqual(pending.phase, .open)
    }

    func testCollapseRequestedClosesFromOpen() {
        var m = machine(.open)
        XCTAssertEqual(m.send(.collapseRequested), [.cancelTimers])
        XCTAssertEqual(m.phase, .closed)
    }

    func testStaleTimersAreNoOps() {
        var m = machine()
        XCTAssertEqual(m.send(.enterDelayElapsed), [])
        XCTAssertEqual(m.send(.exitDelayElapsed), [])
        XCTAssertEqual(m.phase, .closed)

        var open = machine(.open)
        XCTAssertEqual(open.send(.exitDelayElapsed), [])
        XCTAssertEqual(open.phase, .open)
    }

    func testIsExpanded() {
        XCTAssertTrue(NotchPhase.open.isExpanded)
        XCTAssertTrue(NotchPhase.closing.isExpanded)
        XCTAssertFalse(NotchPhase.pending.isExpanded)
        XCTAssertFalse(NotchPhase.peek.isExpanded)
    }
}
