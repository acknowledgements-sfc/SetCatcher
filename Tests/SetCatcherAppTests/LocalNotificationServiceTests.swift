import XCTest
import SetCatcherCore
@testable import SetCatcherApp

final class LocalNotificationServiceTests: XCTestCase {
    func testCaptureStartedBodyUsesRequestedTimeFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 52_320)

        XCTAssertEqual(
            LocalNotificationService.captureStartedBody(displayName: "Serato DJ Pro", at: date, calendar: calendar),
            "Recording started - 14:32"
        )
    }

    func testUrgentBodiesMatchDispatchCopy() {
        let missing = AttentionEvent.folderMissing(appID: "serato", appName: "Serato", path: "/Music")
        XCTAssertEqual(
            LocalNotificationService.urgentBody(for: missing),
            "Recording folder not found — sets may not be protected"
        )
        let screen = AttentionEvent.screenRecordingDenied()
        XCTAssertTrue(LocalNotificationService.urgentBody(for: screen).contains("Screen Recording"))
    }
}
