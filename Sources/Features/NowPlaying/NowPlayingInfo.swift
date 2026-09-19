import Foundation

/// What is playing, from whichever source is working.
struct NowPlayingInfo: Equatable {
    var bundleID: String?
    var title: String
    var artist: String?
    var album: String?
    /// Seconds.
    var duration: TimeInterval?
    /// Seconds elapsed at `timestamp`.
    var elapsed: TimeInterval?
    var timestamp: Date?
    var isPlaying: Bool
    var playbackRate: Double = 1
    /// Raw artwork bytes (JPEG/PNG). Downsampled by `ArtworkProcessor` before display.
    var artworkData: Data?

    /// Identity of the track, ignoring play state and position. A change here is a "track change".
    var trackKey: String {
        [bundleID ?? "", title, artist ?? "", album ?? ""].joined(separator: "\u{1F}")
    }

    /// Current position, extrapolated from the last report while playing.
    func elapsed(at now: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        guard isPlaying, let timestamp else { return elapsed }
        let rate = playbackRate > 0 ? playbackRate : 1
        let position = elapsed + now.timeIntervalSince(timestamp) * rate
        if let duration, duration > 0 {
            return min(max(position, 0), duration)
        }
        return max(position, 0)
    }
}
