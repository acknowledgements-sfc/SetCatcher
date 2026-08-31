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
            isWatchingOrArmed: true
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
            isWatchingOrArmed: true
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
            isWatchingOrArmed: true
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
            isWatchingOrArmed: true
        )
        XCTAssertEqual(LiveProtectionState.derive(input: input), .armed)
    }
}
