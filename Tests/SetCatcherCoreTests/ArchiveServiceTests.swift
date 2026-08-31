import XCTest
@testable import SetCatcherCore

final class ArchiveServiceTests: XCTestCase {
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

    func testEnsureArchiveRootExistsCreatesArchiveFolder() throws {
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        let service = ArchiveService(archiveRoot: archiveRoot)

        XCTAssertFalse(FileManager.default.fileExists(atPath: archiveRoot.path))

        try service.ensureArchiveRootExists()

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveRoot.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testArchiveCopiesSourceAndWritesMetadata() throws {
        let sourceURL = tempRoot.appendingPathComponent("source.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try Data("audio".utf8).write(to: sourceURL)

        let service = ArchiveService(archiveRoot: archiveRoot)
        let session = try service.archive(sourceURL: sourceURL, sourceAppID: "serato", detectedAt: Date(timeIntervalSince1970: 0))

        let archiveURL = try XCTUnwrap(session.archiveURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.metadataURL(for: archiveURL).path))
        XCTAssertEqual(try Data(contentsOf: sourceURL), try Data(contentsOf: archiveURL))
    }

    func testArchiveMetadataIncludesDurationField() throws {
        let sourceURL = tempRoot.appendingPathComponent("source.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try Data("audio".utf8).write(to: sourceURL)

        let service = ArchiveService(archiveRoot: archiveRoot)
        let session = try service.archive(sourceURL: sourceURL, sourceAppID: "serato", detectedAt: Date(timeIntervalSince1970: 0))
        let archiveURL = try XCTUnwrap(session.archiveURL)
        let metadataURL = service.metadataURL(for: archiveURL)
        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(ArchiveMetadata.self, from: data)

        XCTAssertNil(metadata.durationSeconds)
        XCTAssertNotNil(metadata.sourceFingerprint)
    }

    func testArchiveMetadataStoresMeasuredDuration() throws {
        let sourceURL = tempRoot.appendingPathComponent("source.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try Data("audio".utf8).write(to: sourceURL)

        let service = ArchiveService(
            archiveRoot: archiveRoot,
            durationReader: StubAudioDurationReader(duration: 3_661.5)
        )
        let session = try service.archive(sourceURL: sourceURL, sourceAppID: "serato")
        let archiveURL = try XCTUnwrap(session.archiveURL)
        let data = try Data(contentsOf: service.metadataURL(for: archiveURL))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(ArchiveMetadata.self, from: data)

        XCTAssertEqual(metadata.durationSeconds, 3_661.5)
    }

    func testArchiveDoesNotOverwriteExistingArchive() throws {
        let sourceURL = tempRoot.appendingPathComponent("source.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        let detectedAt = Date(timeIntervalSince1970: 0)
        try Data("audio".utf8).write(to: sourceURL)

        let service = ArchiveService(archiveRoot: archiveRoot)
        let first = try service.archive(sourceURL: sourceURL, sourceAppID: "serato", detectedAt: detectedAt)
        let second = try service.archive(sourceURL: sourceURL, sourceAppID: "serato", detectedAt: detectedAt)

        XCTAssertNotEqual(first.archiveURL, second.archiveURL)
        XCTAssertTrue(try XCTUnwrap(second.archiveURL).lastPathComponent.contains(" 2."))
    }

    func testArchiveUsesCustomNamingTemplate() throws {
        let sourceURL = tempRoot.appendingPathComponent("source.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try Data("audio".utf8).write(to: sourceURL)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let service = ArchiveService(
            archiveRoot: archiveRoot,
            calendar: calendar,
            namingTemplate: "{date} - {app} - {source}"
        )
        let session = try service.archive(
            sourceURL: sourceURL,
            sourceAppID: "serato",
            detectedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(
            session.archiveURL?.lastPathComponent,
            "1970-01-01 - Serato DJ Pro - source.wav"
        )
    }

    func testIsSourceAlreadyArchivedUsesMetadataSidecar() throws {
        let sourceURL = tempRoot.appendingPathComponent("source.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try Data("audio".utf8).write(to: sourceURL)

        let service = ArchiveService(archiveRoot: archiveRoot)
        XCTAssertFalse(service.isSourceAlreadyArchived(sourceURL))

        try service.archive(sourceURL: sourceURL, sourceAppID: "serato")

        XCTAssertTrue(service.isSourceAlreadyArchived(sourceURL))
    }

    func testIsSourceAlreadyArchivedUsesFingerprintForRenamedSource() throws {
        let firstSourceURL = tempRoot.appendingPathComponent("source.wav")
        let renamedSourceURL = tempRoot.appendingPathComponent("renamed.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        let audioData = Data("same-recording-content".utf8)
        try audioData.write(to: firstSourceURL)
        try audioData.write(to: renamedSourceURL)

        let service = ArchiveService(archiveRoot: archiveRoot)
        try service.archive(sourceURL: firstSourceURL, sourceAppID: "serato")

        XCTAssertTrue(service.isSourceAlreadyArchived(renamedSourceURL))
    }

    func testDefaultArchiveRootIsMusicSetCatcher() {
        let root = ArchiveService.defaultArchiveRoot()

        XCTAssertTrue(root.path.hasSuffix("/Music/SetCatcher"))
    }

    func testIngestCaptureCopiesStagingWritesMetadataAndRemovesStaging() throws {
        let stagingURL = tempRoot.appendingPathComponent("capture-staging.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try Data("capture-audio".utf8).write(to: stagingURL)
        let service = ArchiveService(archiveRoot: archiveRoot)
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = try service.ingestCapture(stagingURL: stagingURL, deviceID: "djm-v10", deviceName: "DJM-V10", startedAt: startedAt, endedAt: startedAt.addingTimeInterval(120))
        XCTAssertEqual(session.sourceAppID, SupportedDJSoftware.captureAppID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagingURL.path))
        let archiveURL = try XCTUnwrap(session.archiveURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.metadataURL(for: archiveURL).path))
    }

    func testIngestCaptureRecordsAppAudioVirtualDeviceAttribution() throws {
        let stagingURL = tempRoot.appendingPathComponent("capture-staging.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try Data("capture-audio".utf8).write(to: stagingURL)
        let service = ArchiveService(archiveRoot: archiveRoot)
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = try service.ingestCapture(
            stagingURL: stagingURL,
            deviceID: "serato-virtual-uid",
            deviceName: "Serato Virtual Audio",
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(120),
            sourceAppID: "serato",
            captureRoute: .appAudio,
            captureBackend: .virtualInputDevice,
            captureDeviceTransport: "virtual"
        )
        let archiveURL = try XCTUnwrap(session.archiveURL)
        let data = try Data(contentsOf: service.metadataURL(for: archiveURL))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(ArchiveMetadata.self, from: data)

        XCTAssertEqual(metadata.captureRoute, .appAudio)
        XCTAssertEqual(metadata.captureBackend, .virtualInputDevice)
        XCTAssertEqual(metadata.captureDeviceUID, "serato-virtual-uid")
        XCTAssertEqual(metadata.captureDeviceName, "Serato Virtual Audio")
        XCTAssertEqual(metadata.captureDeviceTransport, "virtual")
        XCTAssertEqual(metadata.sourceAppID, "serato")
    }

    func testArchiveMetadataDecodesLegacySidecarWithoutCaptureFields() throws {
        let json = """
        {
          "sessionID": "00000000-0000-0000-0000-000000000001",
          "sourceAppID": "serato",
          "detectedAt": "2024-01-01T00:00:00Z",
          "completedAt": null,
          "sourcePath": "/source.wav",
          "archivePath": "/archive.wav",
          "fileSize": 12,
          "originalFilename": "source.wav",
          "durationSeconds": null
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(ArchiveMetadata.self, from: json)
        XCTAssertNil(metadata.captureRoute)
        XCTAssertNil(metadata.captureBackend)
        XCTAssertNil(metadata.captureDeviceUID)
        XCTAssertEqual(metadata.sourceAppID, "serato")
    }

    func testVerifyCopiesRejectsSizeMismatchAndRemovesIncompleteCopy() throws {
        let sourceURL = tempRoot.appendingPathComponent("source.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try Data("audio-content".utf8).write(to: sourceURL)

        let service = ArchiveService(
            archiveRoot: archiveRoot,
            fileManager: MismatchingCopyFileManager(),
            verifyCopies: true
        )

        XCTAssertThrowsError(try service.archive(sourceURL: sourceURL, sourceAppID: "serato")) { error in
            guard case ArchiveServiceError.copyVerificationFailed = error else {
                return XCTFail("Expected copyVerificationFailed, got \(error)")
            }
        }

        let leftovers = (try? FileManager.default.contentsOfDirectory(at: archiveRoot, includingPropertiesForKeys: nil)) ?? []
        XCTAssertTrue(leftovers.isEmpty, "Incomplete archive copy must be removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "Source must remain")
    }

    func testIsSourceAlreadyArchivedFalseWhenSamePathContentChanges() throws {
        let sourceURL = tempRoot.appendingPathComponent("source.wav")
        let archiveRoot = tempRoot.appendingPathComponent("Archive", isDirectory: true)
        try Data("original-recording".utf8).write(to: sourceURL)

        let service = ArchiveService(archiveRoot: archiveRoot)
        try service.archive(sourceURL: sourceURL, sourceAppID: "serato")
        XCTAssertTrue(service.isSourceAlreadyArchived(sourceURL))

        try Data("replaced-recording-bytes".utf8).write(to: sourceURL)
        XCTAssertFalse(service.isSourceAlreadyArchived(sourceURL))
    }
}

/// Copies a truncated destination so size verification fails.
private final class MismatchingCopyFileManager: FileManager, @unchecked Sendable {
    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        let data = try Data(contentsOf: srcURL)
        try data.prefix(max(0, data.count - 1)).write(to: dstURL)
    }
}

private struct StubAudioDurationReader: AudioDurationReading {
    let duration: Double?

    func durationSeconds(for url: URL) -> Double? {
        duration
    }
}
