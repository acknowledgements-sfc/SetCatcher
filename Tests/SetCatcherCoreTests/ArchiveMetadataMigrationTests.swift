import XCTest
@testable import SetCatcherCore

final class ArchiveMetadataMigrationTests: XCTestCase {
    func testRepairedIfNeededMigratesLegacyAppAudioMisTag() {
        let legacy = ArchiveMetadata(
            sessionID: UUID(),
            sourceAppID: "serato",
            detectedAt: Date(timeIntervalSince1970: 1000),
            completedAt: Date(timeIntervalSince1970: 2000),
            sourcePath: "/SetCatcherCapture/Serato/set.wav",
            archivePath: "/archive/set.wav",
            fileSize: 100,
            originalFilename: "set.wav",
            durationSeconds: 1000,
            captureRoute: .appAudio,
            captureBackend: .screenCaptureKit
        )

        let repaired = ArchiveMetadataMigration.repairedIfNeeded(legacy)

        XCTAssertEqual(repaired.sourceAppID, SupportedDJSoftware.captureAppID)
        XCTAssertEqual(repaired.companionAppID, "serato")
        XCTAssertEqual(repaired.ingestionKind, .capture)
    }

    func testRepairedIfNeededLeavesFolderScanUntouched() {
        let folder = ArchiveMetadata(
            sessionID: UUID(),
            sourceAppID: "serato",
            detectedAt: Date(timeIntervalSince1970: 1000),
            completedAt: Date(timeIntervalSince1970: 2000),
            sourcePath: "/Music/_Serato_/Recording/set.wav",
            archivePath: "/archive/set.wav",
            fileSize: 100,
            originalFilename: "set.wav",
            durationSeconds: 1000,
            ingestionKind: .folderWatch
        )

        XCTAssertEqual(ArchiveMetadataMigration.repairedIfNeeded(folder), folder)
    }
}
