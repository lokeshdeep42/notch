import SwiftUI

/// Round icon button used for transport controls and small actions.
/// Feedback lands on press (not release), and a hover fill makes the hit target discoverable.
public struct PressableButtonStyle: ButtonStyle {
    let diameter: CGFloat

    public init(diameter: CGFloat = 32) {
        self.diameter = diameter
    }

    public func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration, diameter: diameter)
    }

    private struct PressableBody: View {
        let configuration: ButtonStyle.Configuration
        let diameter: CGFloat
        @State private var hovering = false

        var body: some View {
            configuration.label
                .frame(width: diameter, height: diameter)
                .background(
                    Circle().fill(
                        configuration.isPressed ? Palette.fillPressed : (hovering ? Palette.fillHover : Color.clear)
                    )
                )
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .animation(Motion.press, value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

/// Pill-shaped text button for secondary actions ("Clear", "Turn on").
public struct CapsuleButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.caption)
            .tracking(Typography.captionTracking)
            .foregroundStyle(Palette.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(configuration.isPressed ? Palette.fillPressed : Palette.fill))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
