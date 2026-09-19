import CoreGraphics

/// Every fixed dimension of the panel. Nothing is random: sizes are multiples of 4 pt except where
/// they must match hardware.
public enum Metrics {
    /// Width of the fully open panel.
    public static let expandedWidth: CGFloat = 600
    /// Height of the content area below the notch row.
    public static let contentHeight: CGFloat = 148
    /// Height of the cost-receipt footer.
    public static let footerHeight: CGFloat = 22
    /// Extra transparent margin around the expanded panel, so its shadow is not clipped.
    public static let shadowMargin: CGFloat = 24

    /// Outward flare where the shape meets the top edge of the screen.
    public static let topFlareRadius: CGFloat = 6
    public static let collapsedBottomRadius: CGFloat = 10
    public static let expandedBottomRadius: CGFloat = 24

    /// Side "wings" that appear beside the hardware notch while collapsed with live activity.
    public static let wingWidth: CGFloat = 40
    /// Width used for transient peeks (track change, charger).
    public static let peekWingWidth: CGFloat = 110

    public static let contentInset: CGFloat = 16
    public static let cornerSmall: CGFloat = 8
    public static let cornerMedium: CGFloat = 12

    /// Height of a notch-less "pill" on displays without a hardware notch, if the menu bar is hidden.
    public static let minimumPillHeight: CGFloat = 24
}
