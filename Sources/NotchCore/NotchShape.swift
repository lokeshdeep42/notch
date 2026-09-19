import SwiftUI

/// The panel silhouette: a body hanging from the top edge of the screen, horizontally centred in
/// its frame. The top corners flare *outward* to meet the screen edge (so it reads as part of the
/// bezel, like the hardware notch); the bottom corners are ordinary rounded corners.
///
/// Width, height and bottom radius are animatable, so the shape morphs continuously between the
/// collapsed notch and the open panel rather than cross-fading two shapes.
public struct NotchShape: Shape {
    public var width: CGFloat
    public var height: CGFloat
    public var bottomRadius: CGFloat
    public var topFlare: CGFloat
    /// Horizontal shift of the whole body (used when leaning toward a dragged file).
    public var offsetX: CGFloat

    public init(width: CGFloat, height: CGFloat, bottomRadius: CGFloat, topFlare: CGFloat, offsetX: CGFloat = 0) {
        self.width = width
        self.height = height
        self.bottomRadius = bottomRadius
        self.topFlare = topFlare
        self.offsetX = offsetX
    }

    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(width, height), AnimatablePair(bottomRadius, offsetX)) }
        set {
            width = newValue.first.first
            height = newValue.first.second
            bottomRadius = newValue.second.first
            offsetX = newValue.second.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        let w = max(width, 1)
        let h = max(height, 1)
        let midX = rect.midX + offsetX
        let left = midX - w / 2
        let right = midX + w / 2
        let top = rect.minY
        let bottom = top + h
        let flare = min(topFlare, h / 2)
        let radius = min(bottomRadius, h - flare, w / 2)
        // Cubic control distance for a near-continuous ("squircle-like") corner.
        let k: CGFloat = 0.552

        var path = Path()
        path.move(to: CGPoint(x: left - flare, y: top))
        // Outward flare, top-left.
        path.addCurve(
            to: CGPoint(x: left, y: top + flare),
            control1: CGPoint(x: left - flare * (1 - k), y: top),
            control2: CGPoint(x: left, y: top + flare * (1 - k))
        )
        path.addLine(to: CGPoint(x: left, y: bottom - radius))
        // Bottom-left.
        path.addCurve(
            to: CGPoint(x: left + radius, y: bottom),
            control1: CGPoint(x: left, y: bottom - radius * (1 - k)),
            control2: CGPoint(x: left + radius * (1 - k), y: bottom)
        )
        path.addLine(to: CGPoint(x: right - radius, y: bottom))
        // Bottom-right.
        path.addCurve(
            to: CGPoint(x: right, y: bottom - radius),
            control1: CGPoint(x: right - radius * (1 - k), y: bottom),
            control2: CGPoint(x: right, y: bottom - radius * (1 - k))
        )
        path.addLine(to: CGPoint(x: right, y: top + flare))
        // Outward flare, top-right.
        path.addCurve(
            to: CGPoint(x: right + flare, y: top),
            control1: CGPoint(x: right, y: top + flare * (1 - k)),
            control2: CGPoint(x: right + flare * (1 - k), y: top)
        )
        path.closeSubpath()
        return path
    }
}
