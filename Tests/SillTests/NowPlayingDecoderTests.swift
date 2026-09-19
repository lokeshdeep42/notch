import XCTest
@testable import FeatureNowPlaying

final class NowPlayingDecoderTests: XCTestCase {
    private func info(_ output: NowPlayingDecoder.Output?) -> NowPlayingInfo? {
        if case let .info(info)? = output { return info }
        return nil
    }

    func testFullPayloadDecodes() {
        var decoder = NowPlayingDecoder()
        let line = """
        {"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client","playing":true,\
        "title":"Song","artist":"Artist","album":"Album","durationMicros":180000000,\
        "elapsedTimeMicros":30000000,"timestampEpochMicros":1700000000000000,"playbackRate":1}}
        """
        let result = info(decoder.consume(line: line))
        XCTAssertEqual(result?.title, "Song")
        XCTAssertEqual(result?.artist, "Artist")
        XCTAssertEqual(result?.album, "Album")
        XCTAssertEqual(result?.bundleID, "com.spotify.client")
        XCTAssertEqual(result?.isPlaying, true)
        XCTAssertEqual(result?.duration ?? 0, 180, accuracy: 0.001)
        XCTAssertEqual(result?.elapsed ?? 0, 30, accuracy: 0.001)
        XCTAssertEqual(result?.timestamp, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testDiffMergesIntoState() {
        var decoder = NowPlayingDecoder()
        _ = decoder.consume(line: #"{"type":"data","diff":false,"payload":{"title":"A","artist":"X","playing":true}}"#)
        let result = info(decoder.consume(line: #"{"type":"data","diff":true,"payload":{"playing":false}}"#))
        XCTAssertEqual(result?.title, "A")
        XCTAssertEqual(result?.artist, "X")
        XCTAssertEqual(result?.isPlaying, false)
    }

    func testNullRemovesKey() {
        var decoder = NowPlayingDecoder()
        _ = decoder.consume(line: #"{"type":"data","diff":false,"payload":{"title":"A","album":"Z","playing":true}}"#)
        let result = info(decoder.consume(line: #"{"type":"data","diff":true,"payload":{"album":null}}"#))
        XCTAssertNil(result?.album)
        XCTAssertEqual(result?.title, "A")
    }

    func testEmptyPayloadMeansNothingPlaying() {
        var decoder = NowPlayingDecoder()
        _ = decoder.consume(line: #"{"type":"data","diff":false,"payload":{"title":"A","playing":true}}"#)
        XCTAssertEqual(decoder.consume(line: #"{"type":"data","diff":false,"payload":{}}"#), .nothingPlaying)
    }

    func testNonDiffReplacesState() {
        var decoder = NowPlayingDecoder()
        _ = decoder.consume(line: #"{"type":"data","diff":false,"payload":{"title":"A","artist":"X","playing":true}}"#)
        let result = info(decoder.consume(line: #"{"type":"data","diff":false,"payload":{"title":"B","playing":true}}"#))
        XCTAssertEqual(result?.title, "B")
        XCTAssertNil(result?.artist)
    }

    func testMalformedLinesAreIgnored() {
        var decoder = NowPlayingDecoder()
        XCTAssertNil(decoder.consume(line: "not json"))
        XCTAssertNil(decoder.consume(line: #"{"type":"other","payload":{}}"#))
        XCTAssertNil(decoder.consume(line: ""))
    }

    func testArtworkDecodedFromBase64AndClearedByNull() {
        var decoder = NowPlayingDecoder()
        let base64 = Data([0xFF, 0xD8, 0xFF]).base64EncodedString()
        let first = info(decoder.consume(line: #"{"type":"data","diff":false,"payload":{"title":"A","playing":true,"artworkData":"\#(base64)"}}"#))
        XCTAssertEqual(first?.artworkData, Data([0xFF, 0xD8, 0xFF]))
        let second = info(decoder.consume(line: #"{"type":"data","diff":true,"payload":{"artworkData":null}}"#))
        XCTAssertNil(second?.artworkData)
    }

    func testPlainSecondsFieldsAreAccepted() {
        var decoder = NowPlayingDecoder()
        let result = info(decoder.consume(line: #"{"type":"data","diff":false,"payload":{"title":"A","playing":false,"duration":200.5,"elapsedTime":12.25}}"#))
        XCTAssertEqual(result?.duration ?? 0, 200.5, accuracy: 0.001)
        XCTAssertEqual(result?.elapsed ?? 0, 12.25, accuracy: 0.001)
    }

    func testElapsedExtrapolatesOnlyWhilePlaying() {
        let start = Date(timeIntervalSince1970: 1000)
        var playing = NowPlayingInfo(title: "A", duration: 100, elapsed: 10, timestamp: start, isPlaying: true)
        XCTAssertEqual(playing.elapsed(at: start.addingTimeInterval(5)) ?? 0, 15, accuracy: 0.001)
        XCTAssertEqual(playing.elapsed(at: start.addingTimeInterval(500)) ?? 0, 100, accuracy: 0.001, "clamped to duration")
        playing.isPlaying = false
        XCTAssertEqual(playing.elapsed(at: start.addingTimeInterval(5)) ?? 0, 10, accuracy: 0.001)
    }

    func testTrackKeyIgnoresPlayState() {
        let a = NowPlayingInfo(bundleID: "x", title: "A", artist: "B", isPlaying: true)
        var b = a
        b.isPlaying = false
        b.elapsed = 42
        XCTAssertEqual(a.trackKey, b.trackKey)
    }
}
