import AppKit
import CoreGraphics
import DesignSystem

/// Everything about where a panel sits on one screen. Pure value type so the maths is unit-tested.
///
/// Two coordinate spaces are used:
/// - **Screen space** — AppKit global coordinates (bottom-left origin, secondary displays may have
///   negative origins). Only `screenFrame` and `windowFrame()` are in screen space.
/// - **Panel space** — the panel's content view, flipped: origin at the window's top-left, y grows
///   downward. Every other rect here is in panel space.
public struct NotchGeometry: Equatable, Sendable {
    public let screenFrame: CGRect
    public let notchSize: CGSize
    public let hasHardwareNotch: Bool

    /// Horizontal slack around the notch that still counts as "hovering the notch".
    public static let hoverMarginX: CGFloat = 10
    /// How far below the notch the hover zone extends.
    public static let hoverMarginBottom: CGFloat = 6

    public init(screenFrame: CGRect, notchSize: CGSize, hasHardwareNotch: Bool) {
        self.screenFrame = screenFrame
        self.notchSize = notchSize
        self.hasHardwareNotch = hasHardwareNotch
    }

    /// Builds geometry from raw screen measurements.
    /// - Parameters:
    ///   - auxLeftWidth/auxRightWidth: widths of `NSScreen.auxiliaryTopLeftArea/RightArea`, nil if absent.
    ///   - menuBarHeight: `frame.maxY - visibleFrame.maxY`; 0 when the menu bar auto-hides.
    ///   - fallbackWidth: user's preferred pill width for screens without a notch.
    public static func resolve(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxLeftWidth: CGFloat?,
        auxRightWidth: CGFloat?,
        menuBarHeight: CGFloat,
        fallbackWidth: CGFloat
    ) -> NotchGeometry {
        if safeAreaTop > 0, let left = auxLeftWidth, let right = auxRightWidth {
            let width = screenFrame.width - left - right
            if width > 0 {
                return NotchGeometry(
                    screenFrame: screenFrame,
                    notchSize: CGSize(width: width, height: safeAreaTop),
                    hasHardwareNotch: true
                )
            }
        }
        let height = max(menuBarHeight, Metrics.minimumPillHeight)
        let width = min(max(fallbackWidth, 120), 320)
        return NotchGeometry(
            screenFrame: screenFrame,
            notchSize: CGSize(width: width, height: height),
            hasHardwareNotch: false
        )
    }

    @MainActor
    public static func resolve(screen: NSScreen, fallbackWidth: CGFloat) -> NotchGeometry {
        resolve(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxRightWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY,
            fallbackWidth: fallbackWidth
        )
    }

    // MARK: Sizes

    public var expandedHeight: CGFloat {
        notchSize.height + Metrics.contentHeight + Metrics.footerHeight
    }

    public var windowSize: CGSize {
        CGSize(
            width: Metrics.expandedWidth + Metrics.shadowMargin * 2,
            height: expandedHeight + Metrics.shadowMargin
        )
    }

    // MARK: Screen space

    /// The panel window's frame: fixed at the maximum expanded size, anchored top-centre.
    /// It is set once and never animated.
    public func windowFrame() -> CGRect {
        let size = windowSize
        return CGRect(
            x: (screenFrame.midX - size.width / 2).rounded(),
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    // MARK: Panel space (flipped)

    private var centerX: CGFloat { windowSize.width / 2 }

    /// The collapsed shape, optionally widened symmetrically by `extraWidth` on each side (wings).
    public func collapsedRect(extraWidth: CGFloat = 0) -> CGRect {
        let width = notchSize.width + extraWidth * 2
        return CGRect(x: centerX - width / 2, y: 0, width: width, height: notchSize.height)
    }

    public func expandedRect() -> CGRect {
        CGRect(x: Metrics.shadowMargin, y: 0, width: Metrics.expandedWidth, height: expandedHeight)
    }

    /// Where hovering counts while collapsed. The top `deadZone` points are excluded so a pointer
    /// thrown at the menu bar (which ends up pinned at the top edge) does not open the panel.
    public func hoverRect(deadZone: CGFloat, extraWidth: CGFloat = 0) -> CGRect {
        let base = collapsedRect(extraWidth: extraWidth)
        let top = min(max(deadZone, 0), base.height - 1)
        return CGRect(
            x: base.minX - Self.hoverMarginX,
            y: top,
            width: base.width + Self.hoverMarginX * 2,
            height: base.height + Self.hoverMarginBottom - top
        )
    }

    /// Converts a point from screen space to panel space.
    public func panelPoint(fromScreen point: CGPoint) -> CGPoint {
        let frame = windowFrame()
        return CGPoint(x: point.x - frame.minX, y: frame.maxY - point.y)
    }
}
