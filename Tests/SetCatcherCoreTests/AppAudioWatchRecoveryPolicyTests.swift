import XCTest
@testable import SetCatcherCore

final class AppAudioWatchRecoveryPolicyTests: XCTestCase {
    func testDoesNotRearmWhileIdleOrArmed() {
        XCTAssertFalse(
            AppAudioWatchRecoveryPolicy.shouldRearm(
                phase: .idle,
                isMonitoring: false,
                monitoredBundleIdentifier: "",
                shareableBundleIdentifiers: ["com.serato.seratodj"]
            )
        )
        XCTAssertFalse(
            AppAudioWatchRecoveryPolicy.shouldRearm(
                phase: .armed,
                isMonitoring: false,
                monitoredBundleIdentifier: "",
                shareableBundleIdentifiers: ["com.serato.seratodj"]
            )
        )
    }

    func testRearmsDeadTapWhileWatching() {
        XCTAssertTrue(
            AppAudioWatchRecoveryPolicy.shouldRearm(
                phase: .watching,
                isMonitoring: false,
                monitoredBundleIdentifier: "com.serato.seratodj",
                shareableBundleIdentifiers: ["com.serato.seratodj"]
            )
        )
    }

    func testRearmsWhenMonitoredAppHasQuit() {
        XCTAssertTrue(
            AppAudioWatchRecoveryPolicy.shouldRearm(
                phase: .watching,
                isMonitoring: true,
                monitoredBundleIdentifier: "com.serato.seratodj",
                shareableBundleIdentifiers: ["com.pioneerdj.rekordboxdj"]
            )
        )
    }

    func testDoesNotRearmHealthyTap() {
        XCTAssertFalse(
            AppAudioWatchRecoveryPolicy.shouldRearm(
                phase: .watching,
                isMonitoring: true,
                monitoredBundleIdentifier: "com.serato.seratodj",
                shareableBundleIdentifiers: ["com.serato.seratodj"]
            )
        )
    }

    func testDoesNotRearmWhileRecording() {
        XCTAssertFalse(
            AppAudioWatchRecoveryPolicy.shouldRearm(
                phase: .recording,
                isMonitoring: false,
                monitoredBundleIdentifier: "com.serato.seratodj",
                shareableBundleIdentifiers: ["com.pioneerdj.rekordboxdj"]
            )
        )
    }

    func testFinalizesAbandonedRecordingWhenSourceHasQuit() {
        XCTAssertTrue(
            AppAudioWatchRecoveryPolicy.shouldFinalizeAbandonedRecording(
                phase: .recording,
                monitoredBundleIdentifier: "com.pioneerdj.rekordboxdj",
                shareableBundleIdentifiers: ["com.serato.seratodj"]
            )
        )
        XCTAssertTrue(
            AppAudioWatchRecoveryPolicy.shouldFinalizeAbandonedRecording(
                phase: .recording,
                monitoredBundleIdentifier: "com.pioneerdj.rekordboxdj",
                shareableBundleIdentifiers: []
            )
        )
    }

    func testDoesNotFinalizeLiveRecordingWhileSourceStillShareable() {
        XCTAssertFalse(
            AppAudioWatchRecoveryPolicy.shouldFinalizeAbandonedRecording(
                phase: .recording,
                monitoredBundleIdentifier: "com.pioneerdj.rekordboxdj",
                shareableBundleIdentifiers: ["com.pioneerdj.rekordboxdj", "com.serato.seratodj"]
            )
        )
        XCTAssertFalse(
            AppAudioWatchRecoveryPolicy.shouldFinalizeAbandonedRecording(
                phase: .watching,
                monitoredBundleIdentifier: "com.pioneerdj.rekordboxdj",
                shareableBundleIdentifiers: ["com.serato.seratodj"]
            )
        )
    }
}
