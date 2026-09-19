import SwiftUI

/// The panel is pure black so it is continuous with the hardware notch — any tint or glass would
/// reveal the seam. Hierarchy comes from white at different opacities, not from grey fills.
public enum Palette {
    public static let panel = Color.black
    public static let primary = Color.white.opacity(0.95)
    public static let secondary = Color.white.opacity(0.62)
    public static let tertiary = Color.white.opacity(0.40)
    public static let hairline = Color.white.opacity(0.08)
    public static let fill = Color.white.opacity(0.07)
    public static let fillHover = Color.white.opacity(0.12)
    public static let fillPressed = Color.white.opacity(0.18)
    public static let selection = Color.white.opacity(0.16)
    public static let positive = Color(red: 0.36, green: 0.86, blue: 0.47)
    public static let warning = Color(red: 1.0, green: 0.76, blue: 0.28)
    public static let critical = Color(red: 1.0, green: 0.36, blue: 0.33)
}

/// Size-specific type: tighter tracking as text grows, slightly open tracking when small.
public enum Typography {
    public static let title = Font.system(size: 15, weight: .semibold)
    public static let titleTracking: CGFloat = -0.2
    public static let body = Font.system(size: 13, weight: .regular)
    public static let bodyEmphasis = Font.system(size: 13, weight: .medium)
    public static let caption = Font.system(size: 11, weight: .medium)
    public static let captionTracking: CGFloat = 0.1
    public static let micro = Font.system(size: 10, weight: .medium).monospacedDigit()
    public static let digits = Font.system(size: 11, weight: .medium).monospacedDigit()
    public static let display = Font.system(size: 34, weight: .semibold).monospacedDigit()
    public static let displayTracking: CGFloat = -0.8
}
