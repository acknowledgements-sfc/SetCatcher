import XCTest
@testable import SetCatcherCore

final class LibraryDateFilterTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testTodayIncludesSameDayOnly() {
        let now = date(2026, 8, 9, 15, 0)
        let todayMorning = date(2026, 8, 9, 1, 0)
        let yesterday = date(2026, 8, 8, 23, 0)

        XCTAssertTrue(LibraryDateFilter.today.contains(todayMorning, calendar: calendar, now: now))
        XCTAssertFalse(LibraryDateFilter.today.contains(yesterday, calendar: calendar, now: now))
    }

    func testThisMonthBoundary() {
        let now = date(2026, 8, 9, 12, 0)
        let inMonth = date(2026, 8, 1, 0, 0)
        let priorMonth = date(2026, 7, 31, 23, 0)

        XCTAssertTrue(LibraryDateFilter.thisMonth.contains(inMonth, calendar: calendar, now: now))
        XCTAssertFalse(LibraryDateFilter.thisMonth.contains(priorMonth, calendar: calendar, now: now))
    }

    func testAllAlwaysPasses() {
        XCTAssertTrue(LibraryDateFilter.all.contains(Date.distantPast))
        XCTAssertTrue(LibraryDateFilter.all.contains(Date.distantFuture))
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = h
        components.minute = min
        return calendar.date(from: components)!
    }
}
