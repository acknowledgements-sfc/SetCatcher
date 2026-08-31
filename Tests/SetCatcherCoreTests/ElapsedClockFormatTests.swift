import XCTest
import SetCatcherCore

final class ElapsedClockFormatTests: XCTestCase {
    func testHMSPadsHoursMinutesSeconds() {
        XCTAssertEqual(ElapsedClockFormat.hms(0), "00:00:00")
        XCTAssertEqual(ElapsedClockFormat.hms(5), "00:00:05")
        XCTAssertEqual(ElapsedClockFormat.hms(75), "00:01:15")
        XCTAssertEqual(ElapsedClockFormat.hms(3723), "01:02:03")
    }

    func testHMSClampsNegative() {
        XCTAssertEqual(ElapsedClockFormat.hms(-12), "00:00:00")
    }

    func testMinutesSecondsOmitsHours() {
        XCTAssertEqual(ElapsedClockFormat.minutesSeconds(0), "0:00")
        XCTAssertEqual(ElapsedClockFormat.minutesSeconds(65), "1:05")
        XCTAssertEqual(ElapsedClockFormat.minutesSeconds(3723), "62:03")
    }
}
