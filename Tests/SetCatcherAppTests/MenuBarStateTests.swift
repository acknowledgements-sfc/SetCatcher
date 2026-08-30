import XCTest
import SetCatcherCore
@testable import SetCatcherApp

final class MenuBarStateTests: XCTestCase {
    func testLaunchAndSavedStatesTakePrecedence() {
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: true, justSaved: true, phase: .recording, djAppName: "Serato"),
            .launching
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, justSaved: true, phase: .recording, djAppName: "Serato"),
            .saved
        )
    }

    func testCapturePhasesMapToHonestMenuBarStates() {
        let readyPhases: [CapturePhase] = [.idle, .requestingPermission, .needsScreenRecordingPermission]
        for phase in readyPhases {
            XCTAssertEqual(
                MenuBarState.derive(isLaunching: false, justSaved: false, phase: phase, djAppName: nil),
                .ready
            )
        }

        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, justSaved: false, phase: .armed, djAppName: "Serato"),
            .armed(djAppName: "Serato")
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, justSaved: false, phase: .watching, djAppName: "rekordbox"),
            .armed(djAppName: "rekordbox")
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, justSaved: false, phase: .recording, djAppName: "Traktor"),
            .capturing(djAppName: "Traktor")
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, justSaved: false, phase: .saving, djAppName: nil),
            .saving
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, justSaved: false, phase: .failed("Disk full"), djAppName: nil),
            .failed("Disk full")
        )
    }

    func testOnlyCapturingStateExposesStopCapturePredicate() {
        XCTAssertTrue(MenuBarState.capturing(djAppName: "Serato").isPulsing)
        XCTAssertFalse(MenuBarState.armed(djAppName: "Serato").isPulsing)
        XCTAssertFalse(MenuBarState.saving.isPulsing)
        XCTAssertFalse(MenuBarState.failed("No signal").isPulsing)
    }
}
