import Combine
import DesignSystem
import NotchCore
import Services
import SwiftUI

@MainActor
public final class NowPlayingModule: NotchModule {
    public let id = "nowPlaying"
    public let symbolName = "music.note"
    public var title: String { String(localized: "Now Playing", comment: "Module name") }
    public var isEnabled: Bool { preferences.nowPlayingEnabled }

    private let preferences: Preferences
    private let service = NowPlayingService()
    private weak var host: NotchHost?
    private var cancellables: Set<AnyCancellable> = []
    private var lastWingKey: String?

    public init(preferences: Preferences) {
        self.preferences = preferences
    }

    public func makeExpandedView() -> AnyView {
        AnyView(NowPlayingView(service: service))
    }

    public func activate(host: NotchHost) {
        self.host = host
        service.onTrackChange = { [weak self] info in self?.peek(for: info) }
        service.start()
        service.$info
            .combineLatest(service.$artwork)
            .sink { [weak self] info, artwork in self?.updateWings(info: info, artwork: artwork) }
            .store(in: &cancellables)
    }

    public func deactivate() {
        cancellables.removeAll()
        service.onTrackChange = nil
        service.stop()
        host?.setWings(nil, from: id)
        lastWingKey = nil
        host = nil
    }

    // MARK: Collapsed presence

    /// Wings only while something is actually playing — paused media disappears with the rest.
    /// The content is static (no animated equaliser), so a collapsed notch renders nothing per frame.
    private func updateWings(info: NowPlayingInfo?, artwork: Artwork?) {
        let key = info.map { "\($0.trackKey)|\($0.isPlaying)|\(artwork != nil)" }
        guard key != lastWingKey else { return }
        lastWingKey = key

        guard let info, info.isPlaying else {
            host?.setWings(nil, from: id)
            return
        }
        host?.setWings(
            WingContent(
                priority: 10,
                width: Metrics.wingWidth,
                leading: AnyView(WingArtwork(artwork: artwork, size: 20)),
                trailing: AnyView(PlayingGlyph(tint: artwork?.tint ?? Palette.secondary))
            ),
            from: id
        )
    }

    private func peek(for info: NowPlayingInfo) {
        // Artwork for a new track often arrives a moment after the title; show what we have.
        host?.requestPeek(PeekContent(
            width: Metrics.peekWingWidth,
            leading: AnyView(
                HStack {
                    Spacer(minLength: 0)
                    WingArtwork(artwork: service.artwork, size: 22)
                        .padding(.trailing, 10)
                }
            ),
            trailing: AnyView(
                Text(info.title)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
            )
        ))
    }
}
