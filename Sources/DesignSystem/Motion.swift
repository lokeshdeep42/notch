import AppKit
import SwiftUI

/// Every spring in the app. Values follow Apple's fluid-interface guidance: critically damped by
/// default, a touch of bounce only where the user's gesture carried momentum (the magnetic drag).
/// SwiftUI springs retarget from the on-screen value and keep velocity, so every transition here
/// can be interrupted mid-flight without a jump. Tune on real hardware.
public enum Motion {
    /// Panel growing out of the hardware notch. Near-critical: reads as physical, never wobbly.
    public static let expand = Animation.spring(response: 0.38, dampingFraction: 0.9)
    /// Panel returning into the notch. Fully damped: no overshoot back into the camera housing.
    public static let collapse = Animation.spring(response: 0.30, dampingFraction: 1.0)
    /// Content inside the panel settling after the shape.
    public static let content = Animation.spring(response: 0.28, dampingFraction: 1.0)
    /// The notch leaning toward a dragged file — the only motion driven by a user's momentum.
    public static let magnet = Animation.spring(response: 0.25, dampingFraction: 0.78)
    /// Short, transient notifications (track change, charger connected).
    public static let peek = Animation.spring(response: 0.34, dampingFraction: 0.86)
    /// Press feedback: fast in, so it lands on the same frame as the click.
    public static let press = Animation.spring(response: 0.18, dampingFraction: 1.0)

    /// Content fades in this far behind the shape so the panel reads as opening, not popping.
    public static let contentStagger: Double = 0.05

    /// Used instead of every spring above when Reduce Motion is on.
    public static let crossFade = Animation.easeInOut(duration: 0.2)

    @MainActor
    public static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    @MainActor
    public static func resolved(_ animation: Animation) -> Animation {
        reduceMotion ? crossFade : animation
    }
}
