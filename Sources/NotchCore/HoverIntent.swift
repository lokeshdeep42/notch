import CoreGraphics
import Foundation

/// Reads the pointer's velocity inside the hover zone and decides whether the user *means* to open
/// the panel. This is what separates "I'm reaching for the notch" from "I'm throwing the pointer
/// at the menu bar", instead of relying on a fixed delay alone.
///
/// Points are in AppKit screen coordinates (y grows upward). Samples only arrive from the tracking
/// area's `mouseMoved`, so this costs nothing unless the pointer is already in the zone. A pointer
/// that stops completely sends no samples; the state machine's enter delay covers that case.
public struct HoverIntent: Sendable {
    public struct Config: Equatable, Sendable {
        /// Below this speed (pt/s), a pointer that has been observed long enough is "settled".
        public var settleSpeed: CGFloat = 140
        /// Above this upward speed (pt/s), the pointer is heading for the menu bar.
        public var throwSpeed: CGFloat = 900
        /// Minimum observation time before a slow pointer counts as settled.
        public var minimumObservation: TimeInterval = 0.04
        /// Only samples this recent contribute to the velocity estimate.
        public var window: TimeInterval = 0.1

        public init() {}
    }

    public enum Verdict: Equatable, Sendable {
        case none
        case confirm
        case restart
    }

    private struct Sample: Sendable {
        let point: CGPoint
        let time: TimeInterval
    }

    public var config: Config
    private var samples: [Sample] = []

    public init(config: Config = Config()) {
        self.config = config
    }

    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    public mutating func add(point: CGPoint, time: TimeInterval) -> Verdict {
        samples.append(Sample(point: point, time: time))
        samples.removeAll { time - $0.time > config.window }

        guard samples.count >= 2, let first = samples.first, let last = samples.last else { return .none }
        let span = last.time - first.time
        guard span > 0.001 else { return .none }

        let vx = (last.point.x - first.point.x) / span
        let vy = (last.point.y - first.point.y) / span

        if vy > config.throwSpeed {
            return .restart
        }
        if span >= config.minimumObservation, (vx * vx + vy * vy).squareRoot() < config.settleSpeed {
            return .confirm
        }
        return .none
    }
}
