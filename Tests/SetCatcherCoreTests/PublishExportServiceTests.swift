import XCTest
@testable import SetCatcherCore

final class PublishExportServiceTests: XCTestCase {
    func testExportPackCopiesAudioAndWritesTracklistText() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let archiveFile = temp.appendingPathComponent("set.wav")
        try Data("audio".utf8).write(to: archiveFile)
        let archive = ArchiveMetadata(
            session: RecordingSession(sourceAppID: SupportedDJSoftware.captureAppID, sourceURL: URL(fileURLWithPath: "/SetCatcherCapture/DJM/set.wav"), archiveURL: archiveFile, fileSize: 5, status: .archived),
            originalFilename: "set.wav"
        )
        let tracklist = ImportedTracklist(appID: "rekordbox", sourceURL: URL(fileURLWithPath: "/tmp/h.txt"), tracks: [TrackPlay(title: "Song", artist: "Artist", startTime: nil, source: "h.txt", confidence: 1)])
        let pack = try PublishExportService().exportPack(archive: archive, tracklist: tracklist, destinationDirectory: temp.appendingPathComponent("Out", isDirectory: true))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pack.appendingPathComponent("set.wav").path))
        let exportedTracklist = try String(contentsOf: pack.appendingPathComponent("tracklist.txt"), encoding: .utf8)
        XCTAssertTrue(exportedTracklist.contains("SetCatcher tracklist export"))
        XCTAssertTrue(exportedTracklist.contains("Artist - Song"))
    }
}
