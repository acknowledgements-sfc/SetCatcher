import XCTest
@testable import SetCatcherCore

final class CapturePhaseSleepPreventionTests: XCTestCase {
    func testOnDutyPhasesHoldIdleSleepAssertion() {
        let hold: [CapturePhase] = [.watching, .recording, .saving]
        for phase in hold {
            XCTAssertTrue(
                phase.shouldPreventIdleSleep,
                "\(phase) should prevent idle sleep while Capture is on duty"
            )
        }
    }

    func testOffDutyPhasesDoNotHoldIdleSleepAssertion() {
        let release: [CapturePhase] = [
            .idle,
            .requestingPermission,
            .needsScreenRecordingPermission,
            .armed,
            .failed("device missing"),
        ]
        for phase in release {
            XCTAssertFalse(
                phase.shouldPreventIdleSleep,
                "\(phase) should not prevent idle sleep"
            )
        }
    }

    func testCaptureUIStateIsWatchingOrRecordingMatchesSleepPolicy() {
        var state = CaptureUIState(phase: .watching)
        XCTAssertTrue(state.isWatchingOrRecording)
        state.phase = .armed
        XCTAssertFalse(state.isWatchingOrRecording)
        state.phase = .recording
        XCTAssertTrue(state.isWatchingOrRecording)
        state.phase = .idle
        XCTAssertFalse(state.isWatchingOrRecording)
    }
}
