import AppKit
import DesignSystem
import Services
import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var service: NowPlayingService

    var body: some View {
        ZStack {
            if let info = service.info {
                PlayerView(info: info, service: service)
            } else {
                EmptyMediaView(source: service.source)
            }
            if service.needsAutomationExplanation {
                AutomationExplainer(
                    playerName: service.playerName ?? "Music",
                    onContinue: { service.confirmAutomationExplanation() },
                    onCancel: { service.cancelAutomationExplanation() }
                )
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Metrics.contentInset + 4)
        .animation(Motion.resolved(Motion.content), value: service.needsAutomationExplanation)
    }
}

// MARK: - Player

private struct PlayerView: View {
    let info: NowPlayingInfo
    @ObservedObject var service: NowPlayingService

    var body: some View {
        HStack(spacing: 18) {
            ArtworkView(artwork: service.artwork, size: 104)

            VStack(alignment: .leading, spacing: 2) {
                if let name = service.playerName {
                    HStack(spacing: 5) {
                        if let bundleID = info.bundleID {
                            AppIcon(bundleID: bundleID)
                                .frame(width: 12, height: 12)
                        }
                        Text(name)
                            .font(Typography.caption)
                            .tracking(Typography.captionTracking)
                            .foregroundStyle(Palette.tertiary)
                    }
                    .padding(.bottom, 2)
                }
                Text(info.title)
                    .font(Typography.title)
                    .tracking(Typography.titleTracking)
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 14) {
                    ProgressRow(info: info, tint: service.artwork?.tint ?? Palette.primary,
                                canSeek: service.canSeek, onSeek: { service.seek(to: $0) })
                    if service.canControl {
                        TransportControls(isPlaying: info.isPlaying, service: service)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 112)
        .accessibilityElement(children: .contain)
    }

    private var subtitle: String {
        [info.artist, info.album].compactMap { $0 }.joined(separator: " — ")
    }
}

private struct TransportControls: View {
    let isPlaying: Bool
    @ObservedObject var service: NowPlayingService

    var body: some View {
        HStack(spacing: 4) {
            Button { service.previous() } label: {
                Image(systemName: "backward.fill").font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(PressableButtonStyle(diameter: 32))
            .accessibilityLabel(Text(String(localized: "Previous track", comment: "Transport control")))

            Button { service.togglePlayPause() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressableButtonStyle(diameter: 40))
            .accessibilityLabel(Text(isPlaying
                ? String(localized: "Pause", comment: "Transport control")
                : String(localized: "Play", comment: "Transport control")))

            Button { service.next() } label: {
                Image(systemName: "forward.fill").font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(PressableButtonStyle(diameter: 32))
            .accessibilityLabel(Text(String(localized: "Next track", comment: "Transport control")))
        }
        .foregroundStyle(Palette.primary)
    }
}

/// Position and scrubber. Ticks once per second only while the panel is open and media is playing;
/// the collapsed notch never runs this.
private struct ProgressRow: View {
    let info: NowPlayingInfo
    let tint: Color
    let canSeek: Bool
    let onSeek: @MainActor (TimeInterval) -> Void

    var body: some View {
        if let duration = info.duration, duration > 0 {
            if info.isPlaying {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Scrubber(position: info.elapsed(at: context.date) ?? 0, duration: duration,
                             tint: tint, canSeek: canSeek, onSeek: onSeek)
                }
            } else {
                Scrubber(position: info.elapsed(at: Date()) ?? 0, duration: duration,
                         tint: tint, canSeek: canSeek, onSeek: onSeek)
            }
        } else {
            Spacer(minLength: 0)
        }
    }
}

private struct Scrubber: View {
    let position: TimeInterval
    let duration: TimeInterval
    let tint: Color
    let canSeek: Bool
    let onSeek: @MainActor (TimeInterval) -> Void

    @State private var dragFraction: Double?
    @State private var hovering = false

    var body: some View {
        let fraction = dragFraction ?? min(max(position / duration, 0), 1)
        VStack(spacing: 4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.fill)
                    Capsule().fill(tint.opacity(0.9))
                        .frame(width: max(width * fraction, 0))
                }
                .frame(height: hovering || dragFraction != nil ? 6 : 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard canSeek, width > 0 else { return }
                            dragFraction = min(max(value.location.x / width, 0), 1)
                        }
                        .onEnded { _ in
                            guard canSeek, let fraction = dragFraction else { return }
                            onSeek(fraction * duration)
                            dragFraction = nil
                        }
                )
                .onHover { hovering = canSeek && $0 }
                .animation(Motion.press, value: hovering)
            }
            .frame(height: 10)

            HStack {
                Text(Self.format(fraction * duration))
                Spacer()
                Text("-" + Self.format(max(duration - fraction * duration, 0)))
            }
            .font(Typography.micro)
            .foregroundStyle(Palette.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(localized: "Playback position", comment: "Scrubber")))
        .accessibilityValue(Text("\(Self.format(fraction * duration)) / \(Self.format(duration))"))
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Empty state

private struct EmptyMediaView: View {
    let source: NowPlayingService.Source

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.fill)
                Image(systemName: "music.note")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Palette.tertiary)
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "No media detected", comment: "Now Playing empty state title"))
                    .font(Typography.title)
                    .tracking(Typography.titleTracking)
                    .foregroundStyle(Palette.primary)
                Text(explanation)
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                Button(String(localized: "How Now Playing works", comment: "Help link")) {
                    NSWorkspace.shared.open(Branding.helpURL)
                }
                .buttonStyle(CapsuleButtonStyle())
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 112)
    }

    private var explanation: String {
        switch source {
        case .notifications:
            return String(
                localized: "Play something in Music or Spotify. Other players need the Now Playing helper, which isn't available on this Mac right now.",
                comment: "Now Playing empty state, fallback mode"
            )
        case .adapter, .none:
            return String(
                localized: "Play something in Music, Spotify, a browser, or any app with media controls.",
                comment: "Now Playing empty state"
            )
        }
    }
}

private struct AutomationExplainer: View {
    let playerName: String
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "One question from macOS", comment: "Automation explainer title"))
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Palette.primary)
                Text(String(
                    localized: "To control \(playerName), macOS will ask once whether \(Branding.appName) may send it commands. It only ever sends play, pause and skip.",
                    comment: "Automation explainer body"
                ))
                .font(Typography.caption)
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(String(localized: "Not now", comment: "Button"), action: onCancel)
                .buttonStyle(CapsuleButtonStyle())
            Button(String(localized: "Continue", comment: "Button"), action: onContinue)
                .buttonStyle(CapsuleButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.1)))
    }
}

// MARK: - Pieces

struct ArtworkView: View {
    let artwork: Artwork?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let artwork {
                Image(nsImage: artwork.image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.fill)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.28, weight: .medium))
                    .foregroundStyle(Palette.tertiary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        // The artwork's own colour bleeds softly into the black panel.
        .shadow(color: (artwork?.tint ?? .clear).opacity(0.5), radius: 22)
        .animation(Motion.resolved(Motion.content), value: artwork?.image)
        .accessibilityHidden(true)
    }
}

struct WingArtwork: View {
    let artwork: Artwork?
    let size: CGFloat

    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// Static "playing" mark for the collapsed wing. Deliberately not animated.
struct PlayingGlyph: View {
    let tint: Color

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .accessibilityLabel(Text(String(localized: "Playing", comment: "Collapsed media indicator")))
    }
}

private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
        } else {
            Color.clear
        }
    }
}
