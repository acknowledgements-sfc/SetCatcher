import XCTest
@testable import SetCatcherCore

final class TracklistParserTests: XCTestCase {
    func testDelimitedParserReadsCsvWithHeader() throws {
        let csv = """
        artist,title,start time
        Inner City,Good Life,00:00
        Robin S,Show Me Love,04:12
        """

        let tracks = try DelimitedTracklistParser().parse(data: Data(csv.utf8), sourceName: "test.csv")

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks.first?.artist, "Inner City")
        XCTAssertEqual(tracks.first?.title, "Good Life")
        XCTAssertEqual(tracks.first?.startTime, "00:00")
    }

    func testDelimitedParserReadsTabSeparatedText() throws {
        let text = """
        Artist\tTrack\tTime
        Moodymann\tShades of Jae\t12:01
        """

        let tracks = try DelimitedTracklistParser().parse(data: Data(text.utf8), sourceName: "test.txt")

        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.artist, "Moodymann")
        XCTAssertEqual(tracks.first?.title, "Shades of Jae")
    }

    func testSeratoHistoryParserUsesDelimitedParser() throws {
        let csv = """
        artist,title
        Stardust,Music Sounds Better With You
        """

        let tracks = try SeratoHistoryParser().parse(data: Data(csv.utf8))

        XCTAssertEqual(tracks.first?.source, "Serato History")
        XCTAssertEqual(tracks.first?.title, "Music Sounds Better With You")
    }

    func testSeratoHistoryParserReadsNameColumnAsTitleAndSkipsSessionSummary() throws {
        let csv = """
        "name","start time","end time","playtime","deck","notes","added","comment","","bitrate","location"
        "4/9/22","4/9/22, 7:55:45 PM PDT","4/10/22, 12:20:16 PM PDT","16:24:31","","","","","","",""
        "Dang! (feat. Anderson .Paak)","7:55:45 PM PDT","7:58:06 PM PDT","00:02:21","1","","","","","",""
        "TRACK UNO","7:56:15 PM PDT","8:01:15 PM PDT","00:05:00","2","","","","","",""
        """

        let tracks = try SeratoHistoryParser().parse(data: Data(csv.utf8), sourceName: "4-9-22.csv")

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks.first?.artist, "")
        XCTAssertEqual(tracks.first?.title, "Dang! (feat. Anderson .Paak)")
        XCTAssertEqual(tracks.first?.startTime, "7:55:45 PM PDT")
    }

    func testDelimitedParserDecodesHtmlEntities() throws {
        let csv = """
        name,start time
        Big Pimpin&#39;,8:11:00 PM PDT
        """

        let tracks = try SeratoHistoryParser().parse(data: Data(csv.utf8), sourceName: "test.csv")

        XCTAssertEqual(tracks.first?.title, "Big Pimpin'")
    }

    func testRekordboxXMLParserReadsCollectionTracks() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <DJ_PLAYLISTS Version="1.0.0">
          <COLLECTION Entries="2">
            <TRACK TrackID="1" Name="Plastic Dreams" Artist="Jaydee" />
            <TRACK TrackID="2" Name="Deep Inside" Artist="Hardrive" />
          </COLLECTION>
        </DJ_PLAYLISTS>
        """

        let tracks = try RekordboxXMLParser().parse(data: Data(xml.utf8), sourceName: "rekordbox.xml")

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks.first?.title, "Plastic Dreams")
        XCTAssertEqual(tracks.first?.artist, "Jaydee")
        XCTAssertEqual(tracks.first?.source, "rekordbox.xml")
    }

    func testTraktorNMLParserReadsEntryAttributes() throws {
        let nml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NML VERSION="19">
          <PLAYLISTS>
            <NODE NAME="History">
              <PLAYLIST>
                <ENTRY TITLE="Jaguar" ARTIST="DJ Rolando" STARTTIME="00:00" />
                <ENTRY TITLE="Can You Feel It" ARTIST="Mr. Fingers" STARTTIME="05:22" />
              </PLAYLIST>
            </NODE>
          </PLAYLISTS>
        </NML>
        """

        let tracks = try TraktorNMLParser().parse(data: Data(nml.utf8), sourceName: "history.nml")

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks.first?.title, "Jaguar")
        XCTAssertEqual(tracks.first?.artist, "DJ Rolando")
        XCTAssertEqual(tracks.first?.startTime, "00:00")
        XCTAssertEqual(tracks.first?.source, "history.nml")
    }

    func testVirtualDJHistoryParserReadsDatabaseSongAttributes() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <VirtualDJ_Database Version="8">
          <Song FilePath="/Music/Inner City - Good Life.mp3" Title="Good Life" Author="Inner City" />
          <Song FilePath="/Music/Robin S - Show Me Love.mp3" Title="Show Me Love" Author="Robin S" />
        </VirtualDJ_Database>
        """

        let tracks = try VirtualDJHistoryParser().parse(data: Data(xml.utf8), sourceName: "database.xml")

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks.first?.title, "Good Life")
        XCTAssertEqual(tracks.first?.artist, "Inner City")
    }

    func testVirtualDJHistoryParserReadsM3UEntries() throws {
        let m3u = """
        #EXTM3U
        #EXTINF:351,Inner City - Good Life
        /Music/Inner City - Good Life.mp3
        #EXTINF:320,Robin S - Show Me Love
        /Music/Robin S - Show Me Love.mp3
        """

        let tracks = try VirtualDJHistoryParser().parse(data: Data(m3u.utf8), sourceName: "history.m3u")

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks.first?.title, "Good Life")
        XCTAssertEqual(tracks.first?.artist, "Inner City")
    }

    func testVirtualDJHistoryParserFallsBackToDelimitedText() throws {
        let text = """
        Artist,Title,Time
        Cajmere,Percolator,00:00
        """

        let tracks = try VirtualDJHistoryParser().parse(data: Data(text.utf8), sourceName: "history.txt")

        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.title, "Percolator")
        XCTAssertEqual(tracks.first?.artist, "Cajmere")
    }

    func testJSONLParserKeepsOnlyTrackPlayEventsInOrder() throws {
        let jsonl = """
        {"v":1,"type":"session_start","ts":"2026-08-12T21:00:00Z","session":"5B6E","plugin":"1.0.0","app":"virtualdj"}
        {"v":1,"type":"track_load","ts":"2026-08-12T21:04:00Z","session":"5B6E","deck":1,"artist":"Inner City","title":"Good Life"}
        {"v":1,"type":"track_play","ts":"2026-08-12T21:05:00Z","session":"5B6E","deck":1,"artist":"Inner City","title":"Good Life","elapsed":0.0}
        {"v":1,"type":"track_play","ts":"2026-08-12T21:11:00Z","session":"5B6E","deck":2,"artist":"Robin S","title":"Show Me Love"}
        {"v":1,"type":"session_end","ts":"2026-08-12T22:00:00Z","session":"5B6E"}
        """

        let tracks = try JSONLTracklistParser().parse(data: Data(jsonl.utf8), sourceName: "set-2026-08-12-5B6E.jsonl")

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks.first?.title, "Good Life")
        XCTAssertEqual(tracks.first?.artist, "Inner City")
        XCTAssertEqual(tracks.first?.startTime, "2026-08-12T21:05:00Z")
        XCTAssertEqual(tracks.first?.source, JSONLTracklistParser.source)
        XCTAssertEqual(tracks.first?.confidence, JSONLTracklistParser.confidence)
        XCTAssertEqual(tracks.last?.title, "Show Me Love")
    }

    func testJSONLParserCollapsesReCueRepeatOnSameDeck() throws {
        let jsonl = """
        {"v":1,"type":"track_play","ts":"2026-08-12T21:05:00Z","deck":1,"artist":"Cajmere","title":"Percolator"}
        {"v":1,"type":"track_play","ts":"2026-08-12T21:05:12Z","deck":1,"artist":"Cajmere","title":"Percolator"}
        {"v":1,"type":"track_play","ts":"2026-08-12T21:09:00Z","deck":2,"artist":"Green Velvet","title":"Flash"}
        """

        let tracks = try JSONLTracklistParser().parse(data: Data(jsonl.utf8), sourceName: "session.jsonl")

        XCTAssertEqual(tracks.map(\.title), ["Percolator", "Flash"])
    }

    func testJSONLParserToleratesTruncatedFinalLine() throws {
        let jsonl = """
        {"v":1,"type":"track_play","artist":"Cajmere","title":"Percolator"}
        {"v":1,"type":"track_play","artist":"Half-writ
        """

        let tracks = try JSONLTracklistParser().parse(data: Data(jsonl.utf8), sourceName: "session.jsonl")

        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.title, "Percolator")
    }

    func testJSONLParserRejectsUnknownMajorVersion() throws {
        let jsonl = #"{"v":2,"type":"track_play","artist":"A","title":"B"}"#

        XCTAssertThrowsError(
            try JSONLTracklistParser().parse(data: Data(jsonl.utf8), sourceName: "session.jsonl")
        ) { error in
            XCTAssertEqual(error as? TracklistParserError, .unsupportedVersion(2))
        }
    }

    func testVirtualDJHistoryParserRoutesJSONLToPluginParser() throws {
        let jsonl = #"{"v":1,"type":"track_play","artist":"Rhythim Is Rhythim","title":"Strings of Life"}"#

        let tracks = try VirtualDJHistoryParser().parse(data: Data(jsonl.utf8), sourceName: "set.jsonl")

        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.title, "Strings of Life")
        XCTAssertEqual(tracks.first?.confidence, JSONLTracklistParser.confidence)
    }
}
