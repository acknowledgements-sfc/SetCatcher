import XCTest
@testable import SetCatcherCore

final class FileStabilityCheckerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SetCatcherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
    }

    func testRecentAudioFilesOnlyReturnsAudioFiles() throws {
        let wavURL = tempRoot.appendingPathComponent("set.wav")
        let textURL = tempRoot.appendingPathComponent("notes.txt")
        try Data("audio".utf8).write(to: wavURL)
        try Data("notes".utf8).write(to: textURL)

        let checker = FileStabilityChecker()
        let urls = try checker.recentAudioFiles(in: tempRoot, modifiedAfter: .distantPast)

        XCTAssertEqual(urls.map(\.lastPathComponent), [wavURL.lastPathComponent])
    }

    func testRecentAudioFilesCanFilterByStableBeforeDate() throws {
        let oldURL = tempRoot.appendingPathComponent("old.wav")
        let newURL = tempRoot.appendingPathComponent("new.wav")
        try Data("audio".utf8).write(to: oldURL)
        try Data("audio".utf8).write(to: newURL)

        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldURL.path)
        try FileManager.default.setAttributes([.modificationDate: newDate], ofItemAtPath: newURL.path)

        let urls = try FileStabilityChecker().recentAudioFiles(
            in: tempRoot,
            modifiedAfter: .distantPast,
            stableBefore: Date(timeIntervalSince1970: 150)
        )

        XCTAssertEqual(urls.map(\.lastPathComponent), [oldURL.lastPathComponent])
    }

    func testRecentUnstableAudioFilesReturnsFilesInsideStabilityWindow() throws {
        let stableURL = tempRoot.appendingPathComponent("stable.wav")
        let unstableURL = tempRoot.appendingPathComponent("recording.wav")
        try Data("audio".utf8).write(to: stableURL)
        try Data("audio".utf8).write(to: unstableURL)

        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: stableURL.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 200)],
            ofItemAtPath: unstableURL.path
        )

        let urls = try FileStabilityChecker().recentUnstableAudioFiles(
            in: tempRoot,
            modifiedAfter: .distantPast,
            unstableAfter: Date(timeIntervalSince1970: 150)
        )

        XCTAssertEqual(urls.map(\.lastPathComponent), [unstableURL.lastPathComponent])
    }

    func testIsStableComparesCurrentSnapshotToPreviousSnapshot() throws {
        let wavURL = tempRoot.appendingPathComponent("set.wav")
        try Data("audio".utf8).write(to: wavURL)

        let checker = FileStabilityChecker()
        let snapshot = try checker.snapshot(for: wavURL)

        XCTAssertTrue(try checker.isStable(url: wavURL, previousSnapshot: snapshot))
    }
}
