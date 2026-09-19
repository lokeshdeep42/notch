import XCTest
@testable import NotchCore

final class HoverIntentTests: XCTestCase {
    func testSingleSampleIsUndecided() {
        var intent = HoverIntent()
        XCTAssertEqual(intent.add(point: CGPoint(x: 100, y: 100), time: 0), .none)
    }

    func testSlowDriftAfterObservationConfirms() {
        var intent = HoverIntent()
        // 2 pt over 50 ms = 40 pt/s, observed long enough.
        XCTAssertEqual(intent.add(point: CGPoint(x: 100, y: 100), time: 0), .none)
        XCTAssertEqual(intent.add(point: CGPoint(x: 101, y: 100), time: 0.02), .none)
        XCTAssertEqual(intent.add(point: CGPoint(x: 102, y: 100), time: 0.05), .confirm)
    }

    func testSlowButTooBriefIsUndecided() {
        var intent = HoverIntent()
        _ = intent.add(point: CGPoint(x: 100, y: 100), time: 0)
        XCTAssertEqual(intent.add(point: CGPoint(x: 100.5, y: 100), time: 0.02), .none)
    }

    func testFastUpwardThrowRestarts() {
        var intent = HoverIntent()
        _ = intent.add(point: CGPoint(x: 100, y: 100), time: 0)
        // +30 pt upward in 20 ms = 1500 pt/s.
        XCTAssertEqual(intent.add(point: CGPoint(x: 100, y: 130), time: 0.02), .restart)
    }

    func testFastDownwardIsNotAThrow() {
        var intent = HoverIntent()
        _ = intent.add(point: CGPoint(x: 100, y: 130), time: 0)
        XCTAssertEqual(intent.add(point: CGPoint(x: 100, y: 100), time: 0.02), .none)
    }

    func testFastSidewaysIsUndecided() {
        var intent = HoverIntent()
        _ = intent.add(point: CGPoint(x: 100, y: 100), time: 0)
        XCTAssertEqual(intent.add(point: CGPoint(x: 160, y: 100), time: 0.05), .none)
    }

    func testOldSamplesFallOutOfWindow() {
        var intent = HoverIntent()
        // A fast move long ago must not influence a slow settle now.
        _ = intent.add(point: CGPoint(x: 0, y: 0), time: 0)
        _ = intent.add(point: CGPoint(x: 100, y: 100), time: 1.0)
        _ = intent.add(point: CGPoint(x: 101, y: 100), time: 1.03)
        XCTAssertEqual(intent.add(point: CGPoint(x: 102, y: 100), time: 1.06), .confirm)
    }

    func testResetClearsHistory() {
        var intent = HoverIntent()
        _ = intent.add(point: CGPoint(x: 100, y: 100), time: 0)
        intent.reset()
        XCTAssertEqual(intent.add(point: CGPoint(x: 100, y: 100), time: 0.05), .none)
    }
}
