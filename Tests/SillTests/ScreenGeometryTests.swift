import XCTest
import DesignSystem
@testable import NotchCore

final class ScreenGeometryTests: XCTestCase {
    private let fourteenInch = CGRect(x: 0, y: 0, width: 1512, height: 982)

    func testNotchedScreenMeasuresHardwareCutout() {
        let g = NotchGeometry.resolve(
            screenFrame: fourteenInch, safeAreaTop: 32,
            auxLeftWidth: 663.5, auxRightWidth: 663.5,
            menuBarHeight: 32, fallbackWidth: 200
        )
        XCTAssertTrue(g.hasHardwareNotch)
        XCTAssertEqual(g.notchSize, CGSize(width: 185, height: 32))
    }

    func testNonNotchedScreenUsesFallbackPill() {
        let g = NotchGeometry.resolve(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440), safeAreaTop: 0,
            auxLeftWidth: nil, auxRightWidth: nil,
            menuBarHeight: 25, fallbackWidth: 190
        )
        XCTAssertFalse(g.hasHardwareNotch)
        XCTAssertEqual(g.notchSize, CGSize(width: 190, height: 25))
    }

    func testHiddenMenuBarStillGivesAUsablePill() {
        let g = NotchGeometry.resolve(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0,
            auxLeftWidth: nil, auxRightWidth: nil,
            menuBarHeight: 0, fallbackWidth: 185
        )
        XCTAssertEqual(g.notchSize.height, Metrics.minimumPillHeight)
    }

    func testFallbackWidthIsClamped() {
        let g = NotchGeometry.resolve(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0,
            auxLeftWidth: nil, auxRightWidth: nil,
            menuBarHeight: 24, fallbackWidth: 5000
        )
        XCTAssertEqual(g.notchSize.width, 320)
    }

    func testWindowFrameIsTopCentredOnSecondaryDisplayWithNegativeOrigin() {
        let screen = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let g = NotchGeometry(screenFrame: screen, notchSize: CGSize(width: 185, height: 24), hasHardwareNotch: false)
        let frame = g.windowFrame()
        XCTAssertEqual(frame.maxY, screen.maxY, accuracy: 0.001)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(frame.size, g.windowSize)
    }

    func testCollapsedRectIsCentredAndWidensSymmetrically() {
        let g = NotchGeometry(screenFrame: fourteenInch, notchSize: CGSize(width: 185, height: 32), hasHardwareNotch: true)
        let plain = g.collapsedRect()
        let winged = g.collapsedRect(extraWidth: 40)
        XCTAssertEqual(plain.midX, g.windowSize.width / 2, accuracy: 0.001)
        XCTAssertEqual(winged.midX, plain.midX, accuracy: 0.001)
        XCTAssertEqual(winged.width, plain.width + 80, accuracy: 0.001)
        XCTAssertEqual(plain.minY, 0)
    }

    func testHoverRectExcludesDeadZone() {
        let g = NotchGeometry(screenFrame: fourteenInch, notchSize: CGSize(width: 185, height: 32), hasHardwareNotch: true)
        let hover = g.hoverRect(deadZone: 3)
        XCTAssertEqual(hover.minY, 3)
        XCTAssertEqual(hover.maxY, 32 + NotchGeometry.hoverMarginBottom, accuracy: 0.001)
        XCTAssertFalse(hover.contains(CGPoint(x: hover.midX, y: 1)))
        XCTAssertTrue(hover.contains(CGPoint(x: hover.midX, y: 10)))
    }

    func testDeadZoneNeverSwallowsTheWholeNotch() {
        let g = NotchGeometry(screenFrame: fourteenInch, notchSize: CGSize(width: 185, height: 32), hasHardwareNotch: true)
        XCTAssertGreaterThan(g.hoverRect(deadZone: 500).height, 0)
    }

    func testPanelPointConversion() {
        let g = NotchGeometry(screenFrame: fourteenInch, notchSize: CGSize(width: 185, height: 32), hasHardwareNotch: true)
        let frame = g.windowFrame()
        let p = g.panelPoint(fromScreen: CGPoint(x: frame.minX + 10, y: frame.maxY - 5))
        XCTAssertEqual(p.x, 10, accuracy: 0.001)
        XCTAssertEqual(p.y, 5, accuracy: 0.001)
    }

    func testExpandedRectFitsInsideWindow() {
        let g = NotchGeometry(screenFrame: fourteenInch, notchSize: CGSize(width: 185, height: 32), hasHardwareNotch: true)
        let window = CGRect(origin: .zero, size: g.windowSize)
        XCTAssertTrue(window.contains(g.expandedRect()))
    }
}
