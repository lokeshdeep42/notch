import XCTest
import DesignSystem
import Services
@testable import NotchCore

/// The parts of `docs/04-QA-CHECKLIST.md` §Display matrix that are pure geometry and pure rules.
///
/// These run on any machine, including CI runners with no notch and one virtual display, which is
/// the only reason they exist: the hardware half of that matrix (does the panel's top edge really
/// merge with the cutout, do hover events arrive over it) still needs `docs/VERIFY-ON-MAC.md`.
final class DisplayMatrixTests: XCTestCase {

    // MARK: Fixtures

    /// Nominal point sizes for each Mac's default scaled mode. The notch widths are derived from
    /// the auxiliary areas rather than asserted against Apple's exact figures — the invariants
    /// below are what matter, and the real measurements get recorded in docs/VERIFY-ON-MAC.md.
    struct DisplayFixture {
        let name: String
        let frame: CGRect
        let safeAreaTop: CGFloat
        let notchWidth: CGFloat?
        let menuBarHeight: CGFloat

        func geometry(fallbackWidth: CGFloat = 185) -> NotchGeometry {
            let aux = notchWidth.map { (frame.width - $0) / 2 }
            return NotchGeometry.resolve(
                screenFrame: frame,
                safeAreaTop: safeAreaTop,
                auxLeftWidth: aux,
                auxRightWidth: aux,
                menuBarHeight: menuBarHeight,
                fallbackWidth: fallbackWidth
            )
        }
    }

    static let notched: [DisplayFixture] = [
        .init(name: "MacBook Pro 14\"", frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
              safeAreaTop: 32, notchWidth: 185, menuBarHeight: 32),
        .init(name: "MacBook Pro 16\"", frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
              safeAreaTop: 32, notchWidth: 185, menuBarHeight: 32),
        .init(name: "MacBook Air 13\"", frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
              safeAreaTop: 32, notchWidth: 175, menuBarHeight: 32),
        .init(name: "MacBook Air 15\"", frame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
              safeAreaTop: 32, notchWidth: 175, menuBarHeight: 32),
    ]

    static let notchless: [DisplayFixture] = [
        .init(name: "external QHD", frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
              safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25),
        .init(name: "external 4K HiDPI", frame: CGRect(x: 0, y: 0, width: 3008, height: 1692),
              safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25),
        .init(name: "external 1080p non-HiDPI", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
              safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25),
        .init(name: "iPad as display (Sidecar)", frame: CGRect(x: 0, y: 0, width: 1180, height: 820),
              safeAreaTop: 0, notchWidth: nil, menuBarHeight: 24),
    ]

    static var all: [DisplayFixture] { notched + notchless }

    // MARK: Invariants that must hold on every display

    func testPanelIsWellFormedOnEveryDisplayInTheMatrix() {
        for fixture in Self.all {
            let g = fixture.geometry()
            let label = fixture.name

            XCTAssertEqual(g.hasHardwareNotch, fixture.notchWidth != nil, label)

            let frame = g.windowFrame()
            XCTAssertEqual(frame.size, g.windowSize, label)
            // Anchored to the top of its own screen, horizontally centred there.
            XCTAssertEqual(frame.maxY, fixture.frame.maxY, accuracy: 0.001, label)
            XCTAssertEqual(frame.midX, fixture.frame.midX, accuracy: 0.5, label)
            // Never hangs off a display that is wider and taller than the window itself.
            XCTAssertGreaterThanOrEqual(frame.minX, fixture.frame.minX, label)
            XCTAssertLessThanOrEqual(frame.maxX, fixture.frame.maxX, label)
            XCTAssertGreaterThanOrEqual(frame.minY, fixture.frame.minY, label)

            // The collapsed shape sits dead centre of the window, which is what puts it over the
            // hardware cutout. An off-centre pill here is a visible seam on hardware.
            XCTAssertEqual(g.collapsedRect().midX, g.windowSize.width / 2, accuracy: 0.001, label)
            XCTAssertEqual(g.collapsedRect().minY, 0, label)

            // The open panel fits inside the window it is drawn in.
            XCTAssertTrue(CGRect(origin: .zero, size: g.windowSize).contains(g.expandedRect()), label)

            // The hover zone is usable and covers the bottom edge of the notch.
            let hover = g.hoverRect(deadZone: 3)
            XCTAssertGreaterThan(hover.height, 0, label)
            XCTAssertTrue(hover.contains(CGPoint(x: hover.midX, y: g.notchSize.height)), label)
            XCTAssertFalse(hover.contains(CGPoint(x: hover.midX, y: 0)), label)

            // Screen space to panel space round-trips.
            let p = g.panelPoint(fromScreen: CGPoint(x: frame.minX + 7, y: frame.maxY - 11))
            XCTAssertEqual(p.x, 7, accuracy: 0.001, label)
            XCTAssertEqual(p.y, 11, accuracy: 0.001, label)
        }
    }

    func testNotchedDisplaysMeasureTheCutoutRatherThanTheMenuBar() {
        for fixture in Self.notched {
            let g = fixture.geometry()
            XCTAssertTrue(g.hasHardwareNotch, fixture.name)
            XCTAssertEqual(g.notchSize.height, fixture.safeAreaTop, fixture.name)
            XCTAssertEqual(g.notchSize.width, fixture.notchWidth ?? 0, accuracy: 0.001, fixture.name)
        }
    }

    func testNotchlessDisplaysIgnoreTheUsersPillWidthOnlyWhenItIsOutOfRange() {
        for fixture in Self.notchless {
            XCTAssertEqual(fixture.geometry(fallbackWidth: 200).notchSize.width, 200, fixture.name)
            XCTAssertEqual(fixture.geometry(fallbackWidth: 10).notchSize.width, 120, fixture.name)
            XCTAssertEqual(fixture.geometry(fallbackWidth: 9_000).notchSize.width, 320, fixture.name)
        }
    }

    // MARK: Arrangements — the rows of the matrix that are pure geometry

    /// Each display gets its own window anchored to its own screen, and two panels never overlap.
    private func assertPanelsAreIndependent(_ fixtures: [DisplayFixture], _ label: String) {
        let frames = fixtures.map { fixture -> CGRect in
            let frame = fixture.geometry().windowFrame()
            XCTAssertEqual(frame.maxY, fixture.frame.maxY, accuracy: 0.001, "\(label): \(fixture.name)")
            XCTAssertEqual(frame.midX, fixture.frame.midX, accuracy: 0.5, "\(label): \(fixture.name)")
            return frame
        }
        for i in frames.indices {
            for j in frames.indices where j > i {
                XCTAssertFalse(frames[i].intersects(frames[j]),
                               "\(label): panels for \(fixtures[i].name) and \(fixtures[j].name) overlap")
            }
        }
    }

    func testExternalDisplayToTheLeftWithANegativeOrigin() {
        let builtIn = Self.notched[0]
        let external = DisplayFixture(
            name: "external left", frame: CGRect(x: -2560, y: 0, width: 2560, height: 1440),
            safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25
        )
        assertPanelsAreIndependent([builtIn, external], "external left")
    }

    func testExternalDisplayStackedAboveTheBuiltIn() {
        let builtIn = Self.notched[0]
        let external = DisplayFixture(
            name: "external above", frame: CGRect(x: 0, y: 982, width: 2560, height: 1440),
            safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25
        )
        assertPanelsAreIndependent([builtIn, external], "external above")
    }

    func testTwoExternalsEitherSideOfTheBuiltIn() {
        let left = DisplayFixture(
            name: "external left", frame: CGRect(x: -1920, y: -200, width: 1920, height: 1080),
            safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25
        )
        let right = DisplayFixture(
            name: "external right", frame: CGRect(x: 1512, y: 120, width: 2560, height: 1440),
            safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25
        )
        assertPanelsAreIndependent([left, Self.notched[0], right], "two externals")
    }

    func testMixedHiDPIAndNonHiDPISideBySide() {
        let hiDPI = DisplayFixture(
            name: "4K HiDPI", frame: CGRect(x: 1512, y: 0, width: 3008, height: 1692),
            safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25
        )
        let nonHiDPI = DisplayFixture(
            name: "1080p", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25
        )
        assertPanelsAreIndependent([nonHiDPI, Self.notched[0], hiDPI], "mixed HiDPI")
    }

    /// Clamshell: the lid is shut, so the built-in screen is simply absent from the arrangement
    /// and the external display is the only one left. It must get a deliberate-looking pill.
    func testClamshellLeavesOnlyTheExternalDisplayWithAPill() {
        let external = Self.notchless[0]
        let g = external.geometry()
        XCTAssertFalse(g.hasHardwareNotch)
        XCTAssertEqual(g.notchSize.height, 25)
        XCTAssertEqual(g.windowFrame().maxY, external.frame.maxY, accuracy: 0.001)
    }

    /// Changing resolution or scaling produces a different geometry, which is what makes
    /// `NotchWindowManager.reconcile()` tear the panel down and rebuild it at the new size.
    func testRescalingADisplayChangesGeometrySoThePanelIsRebuilt() {
        let scaled = DisplayFixture(
            name: "2560×1440", frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25
        )
        let rescaled = DisplayFixture(
            name: "1920×1080", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaTop: 0, notchWidth: nil, menuBarHeight: 25
        )
        XCTAssertNotEqual(scaled.geometry(), rescaled.geometry())
        // ...and an unchanged display does not, so reconciliation is idempotent.
        XCTAssertEqual(scaled.geometry(), scaled.geometry())
    }

    // MARK: Which displays get a panel at all

    private func candidate(_ id: CGDirectDisplayID, builtIn: Bool, uuid: String? = nil) -> DisplayCandidate {
        DisplayCandidate(id: id, uuid: uuid ?? "uuid-\(id)", isBuiltIn: builtIn)
    }

    func testBuiltInOnlyPicksTheBuiltInDisplay() {
        let screens = [candidate(1, builtIn: true), candidate(2, builtIn: false)]
        let eligible = DisplayEligibility.eligible(among: screens, mode: .builtInOnly, chosenUUIDs: [])
        XCTAssertEqual(eligible.map(\.id), [1])
    }

    /// Clamshell again, this time as a rule rather than geometry: with the lid shut there is no
    /// built-in display, and "built-in only" must not resolve to nothing.
    func testBuiltInOnlyFallsBackToTheMenuBarDisplayInClamshell() {
        let screens = [candidate(7, builtIn: false), candidate(8, builtIn: false)]
        let eligible = DisplayEligibility.eligible(among: screens, mode: .builtInOnly, chosenUUIDs: [])
        XCTAssertEqual(eligible.map(\.id), [7], "the first screen is the menu-bar display")
    }

    func testAllModeReturnsEveryDisplayInScreenOrder() {
        let screens = [candidate(1, builtIn: true), candidate(2, builtIn: false), candidate(3, builtIn: false)]
        let eligible = DisplayEligibility.eligible(among: screens, mode: .all, chosenUUIDs: [])
        XCTAssertEqual(eligible.map(\.id), [1, 2, 3])
    }

    func testChosenModeMatchesOnUUIDNotDisplayID() {
        let screens = [
            candidate(1, builtIn: true, uuid: "A"),
            candidate(2, builtIn: false, uuid: "B"),
            candidate(3, builtIn: false, uuid: "C"),
        ]
        let eligible = DisplayEligibility.eligible(among: screens, mode: .chosen, chosenUUIDs: ["C", "A"])
        XCTAssertEqual(eligible.map(\.id), [1, 3], "order follows the screens, not the chosen set")
    }

    func testChosenModeFallsBackWhenEveryChosenDisplayIsUnplugged() {
        let screens = [candidate(4, builtIn: true, uuid: "A"), candidate(5, builtIn: false, uuid: "B")]
        let eligible = DisplayEligibility.eligible(among: screens, mode: .chosen, chosenUUIDs: ["gone"])
        XCTAssertEqual(eligible.map(\.id), [4])
    }

    func testCandidatesWithoutAUUIDAreNeverMatchedInChosenMode() {
        let screens = [
            DisplayCandidate(id: 1, uuid: nil, isBuiltIn: true),
            DisplayCandidate(id: 2, uuid: "B", isBuiltIn: false),
        ]
        let eligible = DisplayEligibility.eligible(among: screens, mode: .chosen, chosenUUIDs: ["B", ""])
        XCTAssertEqual(eligible.map(\.id), [2])
    }

    func testNoDisplaysYieldsNoPanels() {
        for mode in DisplayMode.allCases {
            XCTAssertTrue(DisplayEligibility.eligible(among: [], mode: mode, chosenUUIDs: ["A"]).isEmpty,
                          "\(mode)")
        }
    }

    /// Rapid plug/unplug: the rules are pure, so the same arrangement always gives the same answer.
    func testEligibilityIsIdempotentAcrossRepeatedReconciles() {
        let screens = [candidate(1, builtIn: true), candidate(2, builtIn: false)]
        for mode in DisplayMode.allCases {
            let first = DisplayEligibility.eligible(among: screens, mode: mode, chosenUUIDs: ["uuid-2"])
            for _ in 0..<10 {
                XCTAssertEqual(
                    DisplayEligibility.eligible(among: screens, mode: mode, chosenUUIDs: ["uuid-2"]),
                    first, "\(mode)"
                )
            }
        }
    }
}
