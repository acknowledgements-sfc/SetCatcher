import Foundation

public enum LibraryDateFilter: Equatable, Hashable, Sendable {
    case all
    case today
    case thisWeek
    case thisMonth
    case custom(ClosedRange<Date>)

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .thisMonth: return "This month"
        case .custom: return "Custom"
        }
    }

    public static let menuCases: [LibraryDateFilter] = [.all, .today, .thisWeek, .thisMonth]

    public func contains(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .thisWeek:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
            return interval.contains(date)
        case .thisMonth:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return false }
            return interval.contains(date)
        case .custom(let range):
            return range.contains(date)
        }
    }
}
