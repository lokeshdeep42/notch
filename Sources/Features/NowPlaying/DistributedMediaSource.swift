import AppKit
import Services

/// Fallback when the adapter is unavailable: Music and Spotify broadcast their player state as
/// distributed notifications. Listening needs no permission and no polling — a correction to the
/// original spec, which assumed scripting-based polling.
///
/// Limits: no artwork, no position updates between notifications, and nothing is known until the
/// player next changes state. Controls go through Apple Events, which macOS gates behind a one-time
/// Automation prompt; `NowPlayingService` explains it before the first use.
@MainActor
final class DistributedMediaSource {
    enum Player: String, CaseIterable {
        case music = "com.apple.Music"
        case spotify = "com.spotify.client"

        var notificationName: Notification.Name {
            switch self {
            case .music: return Notification.Name("com.apple.Music.playerInfo")
            case .spotify: return Notification.Name("com.spotify.client.PlaybackStateChanged")
            }
        }

        var scriptName: String {
            switch self {
            case .music: return "Music"
            case .spotify: return "Spotify"
            }
        }
    }

    var onChange: ((NowPlayingInfo?) -> Void)?

    private var tokens: [NSObjectProtocol] = []
    private var latest: [Player: NowPlayingInfo] = [:]
    private(set) var activePlayer: Player?

    func start() {
        guard tokens.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        for player in Player.allCases {
            let token = center.addObserver(forName: player.notificationName, object: nil, queue: .main) { [weak self] note in
                let userInfo = note.userInfo ?? [:]
                MainActor.assumeIsolated {
                    self?.handle(userInfo, from: player)
                }
            }
            tokens.append(token)
        }
        Log.media.info("Listening for Music/Spotify notifications")
    }

    func stop() {
        let center = DistributedNotificationCenter.default()
        tokens.forEach { center.removeObserver($0) }
        tokens.removeAll()
        latest.removeAll()
        activePlayer = nil
    }

    static func parse(_ userInfo: [AnyHashable: Any], from player: Player) -> NowPlayingInfo? {
        let state = userInfo["Player State"] as? String ?? ""
        guard state != "Stopped", let title = userInfo["Name"] as? String, !title.isEmpty else { return nil }

        var duration: TimeInterval?
        switch player {
        case .music:
            duration = (userInfo["Total Time"] as? NSNumber).map { $0.doubleValue / 1000 }
        case .spotify:
            duration = (userInfo["Duration"] as? NSNumber).map { $0.doubleValue / 1000 }
        }
        let elapsed = (userInfo["Playback Position"] as? NSNumber)?.doubleValue

        return NowPlayingInfo(
            bundleID: player.rawValue,
            title: title,
            artist: userInfo["Artist"] as? String,
            album: userInfo["Album"] as? String,
            duration: duration,
            elapsed: elapsed,
            timestamp: elapsed == nil ? nil : Date(),
            isPlaying: state == "Playing"
        )
    }

    private func handle(_ userInfo: [AnyHashable: Any], from player: Player) {
        latest[player] = Self.parse(userInfo, from: player)
        // Prefer whichever player is actually playing; otherwise the one that just changed.
        if let playing = latest.first(where: { $0.value.isPlaying }) {
            activePlayer = playing.key
        } else if latest[player] != nil {
            activePlayer = player
        } else {
            activePlayer = latest.keys.first
        }
        onChange?(activePlayer.flatMap { latest[$0] })
    }

    // MARK: Controls (Apple Events)

    enum Action: String {
        case playPause = "playpause"
        case next = "next track"
        case previous = "previous track"
    }

    /// Returns false if macOS refused (Automation permission denied) or the player isn't running.
    @discardableResult
    func perform(_ action: Action) -> Bool {
        guard let player = activePlayer,
              NSRunningApplication.runningApplications(withBundleIdentifier: player.rawValue).isEmpty == false
        else { return false }
        let source = "tell application \"\(player.scriptName)\" to \(action.rawValue)"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            Log.media.error("Apple Events \(action.rawValue, privacy: .public) failed: \(error.description, privacy: .public)")
            return false
        }
        return true
    }
}
