import XCTest
@testable import SetCatcherCore

final class ScanCoordinatorTests: XCTestCase {
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

    func testScanRecentArchivesAudioFromRequestsAndSkipsDuplicateScan() throws {
        let sourceFolder = tempRoot.appendingPathComponent("Source", isDirectory: true)
        let archiveFolder = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)

        let sourceURL = sourceFolder.appendingPathComponent("set.wav")
        let sourceData = Data("audio".utf8)
        try sourceData.write(to: sourceURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 0)],
            ofItemAtPath: sourceURL.path
        )

        let archiveService = ArchiveService(archiveRoot: archiveFolder)
        let scanner = RecordingFolderScanner(archiveService: archiveService)
        let coordinator = ScanCoordinator(scanner: scanner)
        let results = coordinator.scanRecent(
            requests: [FolderScanRequest(appID: "serato", folderURL: sourceFolder)],
            now: Date(timeIntervalSince1970: 120)
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertNil(results.first?.errorDescription)
        XCTAssertEqual(results.first?.archivedSessions.count, 1)

        let archivedSession = try XCTUnwrap(results.first?.archivedSessions.first)
        let archiveURL = try XCTUnwrap(archivedSession.archiveURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveService.metadataURL(for: archiveURL).path))
        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
        XCTAssertEqual(try Data(contentsOf: archiveURL), sourceData)

        let duplicateResults = coordinator.scanRecent(
            requests: [FolderScanRequest(appID: "serato", folderURL: sourceFolder)],
            now: Date(timeIntervalSince1970: 120)
        )

        XCTAssertEqual(duplicateResults.first?.archivedSessions.count, 0)
        XCTAssertEqual(try archivedAudioFileCount(in: archiveFolder), 1)
    }

    func testScanRecentDoesNotArchiveFilesInsideStabilityWindow() throws {
        let sourceFolder = tempRoot.appendingPathComponent("Source", isDirectory: true)
        let archiveFolder = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)

        let sourceURL = sourceFolder.appendingPathComponent("set.wav")
        try Data("audio".utf8).write(to: sourceURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: sourceURL.path
        )

        let scanner = RecordingFolderScanner(
            archiveService: ArchiveService(archiveRoot: archiveFolder)
        )
        let coordinator = ScanCoordinator(scanner: scanner, stabilityWindowSeconds: 30)
        let results = coordinator.scanRecent(
            requests: [FolderScanRequest(appID: "serato", folderURL: sourceFolder)],
            now: Date(timeIntervalSince1970: 120)
        )

        XCTAssertEqual(results.first?.archivedSessions.count, 0)
        XCTAssertEqual(results.first?.pendingRecordingURLs.map(\.lastPathComponent), [sourceURL.lastPathComponent])
        XCTAssertFalse(FileManager.default.fileExists(atPath: archiveFolder.path))
    }

    func testScanRecentReportsStableAndPendingRecordingsSeparately() throws {
        let sourceFolder = tempRoot.appendingPathComponent("Source", isDirectory: true)
        let archiveFolder = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)

        let stableURL = sourceFolder.appendingPathComponent("stable.wav")
        let pendingURL = sourceFolder.appendingPathComponent("pending.wav")
        try Data("stable".utf8).write(to: stableURL)
        try Data("pending".utf8).write(to: pendingURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 60)],
            ofItemAtPath: stableURL.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: pendingURL.path
        )

        let scanner = RecordingFolderScanner(
            archiveService: ArchiveService(archiveRoot: archiveFolder)
        )
        let coordinator = ScanCoordinator(scanner: scanner, stabilityWindowSeconds: 30)
        let results = coordinator.scanRecent(
            requests: [FolderScanRequest(appID: "serato", folderURL: sourceFolder)],
            now: Date(timeIntervalSince1970: 120)
        )

        XCTAssertEqual(results.first?.archivedSessions.count, 1)
        XCTAssertEqual(results.first?.pendingRecordingURLs.map(\.lastPathComponent), [pendingURL.lastPathComponent])
        XCTAssertEqual(try archivedAudioFileCount(in: archiveFolder), 1)
    }

    func testScanRecentCapturesErrorsPerFolder() {
        let missingFolder = tempRoot.appendingPathComponent("Missing", isDirectory: true)
        let coordinator = ScanCoordinator()
        let results = coordinator.scanRecent(
            requests: [FolderScanRequest(appID: "serato", folderURL: missingFolder)]
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(
            results.first?.errorDescription,
            "Recording folder was moved or deleted. Choose the folder again in setup."
        )
    }

    func testScanRecentReportsPlainLanguageErrorWhenPathIsAFile() throws {
        let fileURL = tempRoot.appendingPathComponent("not-a-folder.wav")
        try Data("audio".utf8).write(to: fileURL)

        let coordinator = ScanCoordinator()
        let results = coordinator.scanRecent(
            requests: [FolderScanRequest(appID: "serato", folderURL: fileURL)]
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(
            results.first?.errorDescription,
            "Saved recording folder points to a file. Choose the recording folder again in setup."
        )
    }

    func testScanRecentReportsArchiveFolderUnavailable() throws {
        let sourceFolder = tempRoot.appendingPathComponent("Source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)

        let sourceURL = sourceFolder.appendingPathComponent("set.wav")
        try Data("audio".utf8).write(to: sourceURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 0)],
            ofItemAtPath: sourceURL.path
        )

        let archiveFileURL = tempRoot.appendingPathComponent("Archive")
        try Data("not a folder".utf8).write(to: archiveFileURL)

        let scanner = RecordingFolderScanner(
            archiveService: ArchiveService(archiveRoot: archiveFileURL)
        )
        let coordinator = ScanCoordinator(scanner: scanner)
        let results = coordinator.scanRecent(
            requests: [FolderScanRequest(appID: "serato", folderURL: sourceFolder)],
            now: Date(timeIntervalSince1970: 120)
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(
            results.first?.errorDescription,
            "Archive folder is unavailable. Choose a different archive folder in Settings."
        )
    }

    private func archivedAudioFileCount(in folder: URL) throws -> Int {
        guard FileManager.default.fileExists(atPath: folder.path) else {
            return 0
        }

        let urls = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: nil
        )?.compactMap { $0 as? URL } ?? []

        return urls.filter { $0.pathExtension.lowercased() == "wav" }.count
    }
}
