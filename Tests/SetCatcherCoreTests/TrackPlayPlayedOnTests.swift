import XCTest
@testable import SetCatcherCore

final class TrackPlayPlayedOnTests: XCTestCase {
    func testLegacyTrackDecodesWithoutPlayedOn() throws {
        let json = """
        {
          "id" : "\(UUID().uuidString)",
          "title" : "Song",
          "artist" : "Artist",
          "startTime" : "0:00",
          "source" : "history.csv",
          "confidence" : 1
        }
        """
        let track = try JSONDecoder().decode(TrackPlay.self, from: Data(json.utf8))
        XCTAssertNil(track.playedOn)
        XCTAssertEqual(track.title, "Song")
    }

    func testStampingPlayedOnPreservesIdentity() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let original = TrackPlay(title: "A", artist: "B", startTime: "1:00", source: "s", confidence: 1)
        let stamped = original.stampingPlayedOn(day)
        XCTAssertEqual(stamped.id, original.id)
        XCTAssertEqual(stamped.playedOn, day)
        XCTAssertEqual(stamped.startTime, "1:00")
    }
}
