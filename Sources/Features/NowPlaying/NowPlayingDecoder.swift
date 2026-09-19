import Foundation

/// Decodes the newline-delimited JSON stream of `mediaremote-adapter stream --micros`:
///
///     {"type":"data","diff":false,"payload":{...}}
///
/// A non-diff payload replaces the state; a diff payload is merged into it, and a key whose value
/// is `null` is removed. An empty state means nothing is reporting now-playing information.
/// `bundleIdentifier`, `playing` and `title` are never null when present.
struct NowPlayingDecoder {
    enum Output: Equatable {
        case nothingPlaying
        case info(NowPlayingInfo)
    }

    private var state: [String: Any] = [:]
    /// Artwork is decoded from base64 once per change, not on every position update.
    private var artwork: Data?

    /// Returns nil for lines that carry no state (malformed, or a type we don't use).
    mutating func consume(line: String) -> Output? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "data",
              let payload = object["payload"] as? [String: Any]
        else { return nil }

        let isDiff = object["diff"] as? Bool ?? false
        if !isDiff {
            state = [:]
            artwork = nil
        }
        for (key, value) in payload {
            if value is NSNull {
                state.removeValue(forKey: key)
                if key == "artworkData" { artwork = nil }
            } else if key == "artworkData" {
                artwork = (value as? String).flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
            } else {
                state[key] = value
            }
        }
        return current
    }

    var current: Output {
        guard let title = state["title"] as? String, !title.isEmpty else { return .nothingPlaying }

        var info = NowPlayingInfo(
            bundleID: state["bundleIdentifier"] as? String,
            title: title,
            artist: nonEmpty(state["artist"]),
            album: nonEmpty(state["album"]),
            duration: seconds(micros: "durationMicros", plain: "duration"),
            elapsed: seconds(micros: "elapsedTimeMicros", plain: "elapsedTime"),
            timestamp: timestamp,
            isPlaying: state["playing"] as? Bool ?? false,
            artworkData: artwork
        )
        if let rate = (state["playbackRate"] as? NSNumber)?.doubleValue {
            info.playbackRate = rate
        }
        return .info(info)
    }

    private func nonEmpty(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }

    private func seconds(micros microsKey: String, plain plainKey: String) -> TimeInterval? {
        if let micros = (state[microsKey] as? NSNumber)?.doubleValue {
            return micros / 1_000_000
        }
        return (state[plainKey] as? NSNumber)?.doubleValue
    }

    private var timestamp: Date? {
        if let micros = (state["timestampEpochMicros"] as? NSNumber)?.doubleValue {
            return Date(timeIntervalSince1970: micros / 1_000_000)
        }
        if let string = state["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
        }
        return nil
    }
}
