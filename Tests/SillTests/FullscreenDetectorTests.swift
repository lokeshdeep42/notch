import XCTest
@testable import NotchCore

final class FullscreenDetectorTests: XCTestCase {
    private let display = CGRect(x: 0, y: 0, width: 1512, height: 982)

    func testWindowCoveringWholeDisplayIsFullscreen() {
        XCTAssertTrue(FullscreenDetector.covers(display, display))
    }

    func testZoomedWindowBelowMenuBarIsNot() {
        let zoomed = CGRect(x: 0, y: 32, width: 1512, height: 950)
        XCTAssertFalse(FullscreenDetector.covers(zoomed, display))
    }

    func testWindowOnAnotherDisplayIsNot() {
        let other = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        XCTAssertFalse(FullscreenDetector.covers(other, display))
    }

    func testSecondaryDisplayWithNegativeOrigin() {
        let secondary = CGRect(x: -1920, y: -98, width: 1920, height: 1080)
        XCTAssertTrue(FullscreenDetector.covers(secondary, secondary))
    }
}
