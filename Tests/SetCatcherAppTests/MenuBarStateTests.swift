import XCTest
import SetCatcherCore
@testable import SetCatcherApp

final class MenuBarStateTests: XCTestCase {
    func testLaunchTakesPrecedence() {
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: true, live: .capturing, djAppName: "Serato"),
            .launching
        )
    }

    func testCapturingWinsOverProtectedAndAttention() {
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .capturing, djAppName: "Serato"),
            .capturing(djAppName: "Serato")
        )
    }

    func testProtectedMapsToSaved() {
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .setProtected, djAppName: "Serato"),
            .saved
        )
        XCTAssertEqual(MenuBarState.saved.label, "Protected")
    }

    func testAttentionLabel() {
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .attentionNeeded, djAppName: nil),
            .attentionNeeded
        )
        XCTAssertEqual(MenuBarState.attentionNeeded.label, "Attention")
    }

    func testEightStateLabels() {
        XCTAssertNil(MenuBarState.noSource.label)
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .detected, djAppName: "rekordbox").label,
            "rekordbox"
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .ready, djAppName: "Traktor").label,
            "Traktor"
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .armed, djAppName: "Serato").label,
            "Serato"
        )
        XCTAssertEqual(MenuBarState.saving.label, "Saving…")
    }

    func testLiveStatesMapToMenuBarStates() {
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .noSource, djAppName: nil),
            .noSource
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .detected, djAppName: "djay"),
            .detected(djAppName: "djay")
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .ready, djAppName: "Serato"),
            .ready(djAppName: "Serato")
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .armed, djAppName: "Serato"),
            .armed(djAppName: "Serato")
        )
        XCTAssertEqual(
            MenuBarState.derive(isLaunching: false, live: .saving, djAppName: nil),
            .saving
        )
    }

    func testOnlyCapturingStatePulses() {
        XCTAssertTrue(MenuBarState.capturing(djAppName: "Serato").isPulsing)
        XCTAssertTrue(MenuBarState.launching.isFlashing)
        XCTAssertFalse(MenuBarState.armed(djAppName: "Serato").isPulsing)
        XCTAssertFalse(MenuBarState.saving.isPulsing)
        XCTAssertFalse(MenuBarState.failed("No signal").isPulsing)
        XCTAssertFalse(MenuBarState.attentionNeeded.isPulsing)
    }
}
