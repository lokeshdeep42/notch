import CoreGraphics
import DesignSystem
import SwiftUI

/// Hidden diagnostics in the panel footer: state, display, frame rate.
/// Enable with `defaults write app.sill.Sill DebugOverlay -bool YES` or in Advanced settings.
/// The frame counter only runs while the overlay is visible, which is only while the panel is open.
struct DebugOverlay: View {
    let phase: NotchPhase
    let displayID: CGDirectDisplayID

    @State private var lastFrame: Date?
    @State private var fps: Double = 0

    var body: some View {
        TimelineView(.animation) { context in
            Text(verbatim: "\(String(describing: phase)) · display \(displayID) · \(Int(fps.rounded())) fps")
                .font(Typography.micro)
                .foregroundStyle(Palette.warning.opacity(0.8))
                .onChange(of: context.date) { _, now in
                    if let lastFrame {
                        let delta = now.timeIntervalSince(lastFrame)
                        if delta > 0 { fps = fps * 0.9 + (1 / delta) * 0.1 }
                    }
                    lastFrame = now
                }
        }
    }
}
