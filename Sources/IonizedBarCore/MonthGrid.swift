import Foundation

public enum FirstWeekday: String, CaseIterable, Sendable {
    case system, monday, tuesday, wednesday, thursday, friday, saturday, sunday

    /// As `Calendar` numbers weekdays: 1 is Sunday.
    public func calendarWeekday(system: Int = Calendar.autoupdatingCurrent.firstWeekday) -> Int {
        switch self {
        case .system: system
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }
}

public struct CalendarSettings: Equatable, Sendable {
    public var firstWeekday: FirstWeekday
    public var showsWeekNumbers: Bool

    public init(firstWeekday: FirstWeekday = .system, showsWeekNumbers: Bool = false) {
        self.firstWeekday = firstWeekday
        self.showsWeekNumbers = showsWeekNumbers
    }
}

public struct CalendarDay: Equatable, Sendable {
    public let date: Date
    public let number: Int
    public let isInMonth: Bool
    public let isToday: Bool
}

public struct CalendarWeek: Equatable, Sendable {
    public let number: Int
    public let days: [CalendarDay]
}

/// Gregorian whatever the system's calendar: ISO week numbers are only defined there.
/// Four days in the first week is ISO's rule, and with Monday first this is exactly ISO.
private func gridCalendar(firstWeekday: Int = 2, timeZone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = firstWeekday
    calendar.minimumDaysInFirstWeek = 4
    calendar.timeZone = timeZone
    return calendar
}

/// The rows that hold the days of `month`'s month, and no more.
public func monthGrid(month: Date, today: Date, firstWeekday: Int, timeZone: TimeZone = .autoupdatingCurrent) -> [CalendarWeek] {
    let calendar = gridCalendar(firstWeekday: firstWeekday, timeZone: timeZone)
    let monthInterval = calendar.dateInterval(of: .month, for: month)!
    var weekStart = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)!.start
    var weeks: [CalendarWeek] = []
    while weekStart < monthInterval.end {
        let days = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            return CalendarDay(
                date: date,
                number: calendar.component(.day, from: date),
                isInMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
        weeks.append(CalendarWeek(number: calendar.component(.weekOfYear, from: weekStart), days: days))
        weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
    }
    return weeks
}

public func movedMonth(_ month: Date, by offset: Int, timeZone: TimeZone = .autoupdatingCurrent) -> Date {
    gridCalendar(timeZone: timeZone).date(byAdding: .month, value: offset, to: month)!
}

private func gridFormatter(locale: Locale, timeZone: TimeZone) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = gridCalendar(timeZone: timeZone)
    formatter.timeZone = timeZone
    return formatter
}

public func calendarTitle(month: Date, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
    let formatter = gridFormatter(locale: locale, timeZone: timeZone)
    formatter.setLocalizedDateFormatFromTemplate("MMMMy")
    return formatter.string(from: month)
}

public func calendarWeekdayHeaders(firstWeekday: Int, locale: Locale = .autoupdatingCurrent) -> [String] {
    let utc = TimeZone(identifier: "UTC")!
    let formatter = gridFormatter(locale: locale, timeZone: utc)
    formatter.dateFormat = "ccc"
    // 2026-01-04, a Sunday: weekday n is n - 1 days later.
    let sunday = Date(timeIntervalSince1970: 1767484800)
    return (0..<7).map { offset in
        formatter.string(from: sunday.addingTimeInterval(TimeInterval((firstWeekday - 1 + offset) % 7) * 86400))
    }
}

public func calendarDayAccessibilityLabel(_ day: CalendarDay, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
    let formatter = gridFormatter(locale: locale, timeZone: timeZone)
    formatter.dateStyle = .full
    let date = formatter.string(from: day.date)
    return day.isToday ? "\(date), today" : date
}
