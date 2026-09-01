import SetCatcherCore
import XCTest

final class LiveProtectionStateDeriveTests: XCTestCase {
    func testCapturingWinsOverAttention() {
        let input = LiveProtectionDeriveInput(
            capturePhase: .recording,
            hasSelectedSource: true,
            hasDetectedSource: true,
            hasLiveAttention: true,
            justSaved: false,
            isWatching: true
        )
        XCTAssertEqual(LiveProtectionState.derive(input: input), .capturing)
    }

    func testAttentionWhenNotCapturing() {
        let input = LiveProtectionDeriveInput(
            capturePhase: .watching,
            hasSelectedSource: true,
            hasDetectedSource: true,
            hasLiveAttention: true,
            justSaved: false,
            isWatching: true
        )
        XCTAssertEqual(LiveProtectionState.derive(input: input), .attentionNeeded)
    }

    func testSetProtectedNeverPrimaryDisplay() {
        XCTAssertEqual(LiveProtectionState.setProtected.primaryDisplay, .armed)
    }

    func testJustSavedMapsToSetProtected() {
        let input = LiveProtectionDeriveInput(
            capturePhase: .watching,
            hasSelectedSource: true,
            hasDetectedSource: true,
            hasLiveAttention: false,
            justSaved: true,
            isWatching: true
        )
        XCTAssertEqual(LiveProtectionState.derive(input: input), .setProtected)
    }

    func testWatchingMapsToArmed() {
        let input = LiveProtectionDeriveInput(
            capturePhase: .watching,
            hasSelectedSource: true,
            hasDetectedSource: true,
            hasLiveAttention: false,
            justSaved: false,
            isWatching: true
        )
        XCTAssertEqual(LiveProtectionState.derive(input: input), .armed)
    }

    func testSelectedSourceIsReadyUntilMonitoringActuallyStarts() {
        let input = LiveProtectionDeriveInput(
            capturePhase: .armed,
            hasSelectedSource: true,
            hasDetectedSource: true,
            hasLiveAttention: false,
            justSaved: false,
            isWatching: false
        )
        XCTAssertEqual(LiveProtectionState.derive(input: input), .ready)
    }

    func testNoSourceDetectedAndSavingStates() {
        XCTAssertEqual(
            LiveProtectionState.derive(input: LiveProtectionDeriveInput(
                capturePhase: .idle,
                hasSelectedSource: false,
                hasDetectedSource: false,
                hasLiveAttention: false,
                justSaved: false,
                isWatching: false
            )),
            .noSource
        )
        XCTAssertEqual(
            LiveProtectionState.derive(input: LiveProtectionDeriveInput(
                capturePhase: .idle,
                hasSelectedSource: false,
                hasDetectedSource: true,
                hasLiveAttention: false,
                justSaved: false,
                isWatching: false
            )),
            .detected
        )
        XCTAssertEqual(
            LiveProtectionState.derive(input: LiveProtectionDeriveInput(
                capturePhase: .saving,
                hasSelectedSource: true,
                hasDetectedSource: true,
                hasLiveAttention: true,
                justSaved: false,
                isWatching: false
            )),
            .saving
        )
    }
}
