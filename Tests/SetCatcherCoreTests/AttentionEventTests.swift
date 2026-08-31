import XCTest
@testable import SetCatcherCore

final class AttentionEventTests: XCTestCase {
    func testFolderMissingCopyNamesArchiveSafety() {
        let event = AttentionEvent.folderMissing(
            appID: "serato",
            appName: "Serato DJ Pro",
            path: "/Music/DJ Sets"
        )
        XCTAssertEqual(event.kind, .folderMissing)
        XCTAssertTrue(event.reassurance.contains("already archived"))
        XCTAssertEqual(event.primaryActionTitle, "Fix Folder")
        XCTAssertEqual(event.relatedAppID, "serato")
    }

    func testScreenRecordingNamesFolderProtectionStillWorks() {
        let event = AttentionEvent.screenRecordingDenied()
        XCTAssertEqual(event.kind, .screenRecording)
        XCTAssertTrue(event.reassurance.contains("Folder Protection"))
    }

    func testDiskFullAndSourceUnreadableFactories() {
        let disk = AttentionEvent.diskFull(remainingGigabytes: 1.2)
        XCTAssertEqual(disk.kind, .diskFull)
        XCTAssertTrue(disk.body.contains("1.2"))
        let source = AttentionEvent.sourceUnreadable(sourceName: "Serato DJ Pro")
        XCTAssertEqual(source.kind, .sourceUnreadable)
        XCTAssertTrue(source.body.contains("Serato DJ Pro"))
    }

    func testFolderMovedStoresNewPathForAcceptAction() {
        let event = AttentionEvent.folderMoved(
            appID: "serato",
            fromPath: "/Old/Sets",
            toPath: "/New/Sets"
        )
        XCTAssertEqual(event.kind, .folderMoved)
        XCTAssertEqual(event.relatedPath, "/New/Sets")
        XCTAssertEqual(event.primaryActionTitle, "Use new location")
        XCTAssertTrue(event.reassurance.contains("new location"))
    }

    func testRecoveryPriorityProtectsDestinationBeforeSource() {
        let ordered: [AttentionKind] = [
            .sourceUnreadable, .folderMissing, .diskFull, .permissionDenied, .saveFailed
        ].sorted { $0.recoveryPriority < $1.recoveryPriority }

        XCTAssertEqual(ordered, [.diskFull, .saveFailed, .permissionDenied, .folderMissing, .sourceUnreadable])
    }

    func testSourcePermissionCopyDescribesReadAccess() {
        let event = AttentionEvent.permissionDenied(appID: "serato", path: "/Music/Sets")
        XCTAssertTrue(event.body.contains("can't read"))
        XCTAssertFalse(event.body.contains("write"))
    }

    func testSaveFailureOnlyPromisesTemporaryRecordingWhenRetained() {
        let unavailable = AttentionEvent.saveFailed(reason: "Archive unavailable")
        XCTAssertFalse(unavailable.reassurance.contains("temporary recording is retained"))
        XCTAssertEqual(unavailable.primaryActionTitle, "Open Live")

        let retained = AttentionEvent.saveFailed(
            reason: "Archive unavailable",
            temporaryRecordingRetained: true
        )
        XCTAssertTrue(retained.reassurance.contains("temporary recording is retained"))
        XCTAssertEqual(retained.primaryActionTitle, "Retry Save")
        XCTAssertTrue(retained.secondaryActionTitles.contains("Reveal Temporary Recording"))
    }
}
