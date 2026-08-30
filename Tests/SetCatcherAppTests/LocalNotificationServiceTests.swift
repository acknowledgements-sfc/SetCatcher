import XCTest
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
}
