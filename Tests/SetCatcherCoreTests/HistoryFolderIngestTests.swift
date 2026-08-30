import XCTest
@testable import SetCatcherCore

final class HistoryFolderIngestTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SetCatcherHistoryIngest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
    }

    func testBestCandidatePicksClosestWithinWindow() throws {
        let near = tempRoot.appendingPathComponent("near.csv")
        let far = tempRoot.appendingPathComponent("far.csv")
        try Data("a".utf8).write(to: near)
        try Data("b".utf8).write(to: far)

        let reference = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes(
            [.modificationDate: reference.addingTimeInterval(60)],
            ofItemAtPath: near.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: reference.addingTimeInterval(3_600)],
            ofItemAtPath: far.path
        )

        let best = HistoryFolderIngest().bestCandidate(in: [tempRoot], near: reference)
        XCTAssertEqual(best?.url.lastPathComponent, "near.csv")
    }

    func testBestCandidateIgnoresOutsideWindow() throws {
        let file = tempRoot.appendingPathComponent("old.csv")
        try Data("a".utf8).write(to: file)
        let reference = Date(timeIntervalSince1970: 2_000_000)
        try FileManager.default.setAttributes(
            [.modificationDate: reference.addingTimeInterval(-8 * 60 * 60)],
            ofItemAtPath: file.path
        )

        let best = HistoryFolderIngest().bestCandidate(in: [tempRoot], near: reference)
        XCTAssertNil(best)
    }

    func testIgnoresUnsupportedExtensions() throws {
        let wav = tempRoot.appendingPathComponent("set.wav")
        try Data("x".utf8).write(to: wav)
        XCTAssertTrue(HistoryFolderIngest().candidateFiles(in: [tempRoot]).isEmpty)
    }
}
