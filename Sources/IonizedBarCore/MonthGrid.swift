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

public enum DistanceFormat: String, CaseIterable, Sendable {
    case days, weeksAndDays, yearsMonthsAndDays
}

public struct CalendarSettings: Equatable, Sendable {
    public var firstWeekday: FirstWeekday
    public var showsWeekNumbers: Bool
    public var distanceFormat: DistanceFormat

    public init(firstWeekday: FirstWeekday = .system, showsWeekNumbers: Bool = false, distanceFormat: DistanceFormat = .days) {
        self.firstWeekday = firstWeekday
        self.showsWeekNumbers = showsWeekNumbers
        self.distanceFormat = distanceFormat
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

/// A cell of the month or year selector. `date` is the first day of that month or year.
public struct CalendarPick: Equatable, Sendable {
    public let date: Date
    public let text: String
    public let accessibilityLabel: String
    public let isCurrent: Bool
}

public func calendarMonthPicks(month: Date, today: Date, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> [CalendarPick] {
    let calendar = gridCalendar(timeZone: timeZone)
    let year = calendar.component(.year, from: month)
    return gridFormatter(locale: locale, timeZone: timeZone).standaloneMonthSymbols.enumerated().map { index, text in
        let date = calendar.date(from: DateComponents(year: year, month: index + 1))!
        return CalendarPick(
            date: date,
            text: text,
            accessibilityLabel: calendarTitle(month: date, locale: locale, timeZone: timeZone),
            isCurrent: calendar.isDate(date, equalTo: today, toGranularity: .month)
        )
    }
}

/// On multiples of 12, so that a page holds the same years whichever of them it was reached from.
public func calendarYearPicks(month: Date, today: Date, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> [CalendarPick] {
    let calendar = gridCalendar(timeZone: timeZone)
    let firstYear = calendar.component(.year, from: month) / 12 * 12
    return (firstYear..<firstYear + 12).map { year in
        let date = calendar.date(from: DateComponents(year: year))!
        let text = calendarYearTitle(month: date, locale: locale, timeZone: timeZone)
        return CalendarPick(date: date, text: text, accessibilityLabel: text, isCurrent: calendar.isDate(date, equalTo: today, toGranularity: .year))
    }
}

public func calendarYearTitle(month: Date, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
    let formatter = gridFormatter(locale: locale, timeZone: timeZone)
    formatter.setLocalizedDateFormatFromTemplate("y")
    return formatter.string(from: month)
}

public func calendarYearPageTitle(month: Date, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
    let picks = calendarYearPicks(month: month, today: month, locale: locale, timeZone: timeZone)
    return "\(picks.first!.text) – \(picks.last!.text)"
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

/// In English like the rest of the interface, hence the fixed locale.
public func calendarDistanceText(from today: Date, to date: Date, format: DistanceFormat, timeZone: TimeZone = .autoupdatingCurrent) -> String {
    var calendar = gridCalendar(timeZone: timeZone)
    calendar.locale = Locale(identifier: "en_US")
    let start = calendar.startOfDay(for: today), end = calendar.startOfDay(for: date)
    guard start != end else { return "Today" }
    let isFuture = end > start
    let (from, to) = isFuture ? (start, end) : (end, start)
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = switch format {
    case .days: [.day]
    case .weeksAndDays: [.weekOfMonth, .day]
    case .yearsMonthsAndDays: [.year, .month, .day]
    }
    formatter.calendar = calendar
    formatter.unitsStyle = .full
    formatter.zeroFormattingBehavior = .dropAll
    var text = formatter.string(from: from, to: to)!
    if let lastComma = text.range(of: ", ", options: .backwards) { text.replaceSubrange(lastComma, with: " and ") }
    return isFuture ? "In \(text)" : "\(text) ago"
}

public func calendarDayAccessibilityLabel(_ day: CalendarDay, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
    let formatter = gridFormatter(locale: locale, timeZone: timeZone)
    formatter.dateStyle = .full
    let date = formatter.string(from: day.date)
    return day.isToday ? "\(date), today" : date
}
