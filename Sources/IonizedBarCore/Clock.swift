import Foundation

public enum TimeFormat: String, CaseIterable, Sendable {
    case system, twelveHour, twentyFourHour
}

public enum DateFormat: String, CaseIterable, Sendable {
    case system, iso, dayMonthYear
}

public struct ClockSettings: Equatable, Sendable {
    public var isShown: Bool
    public var showsSeconds: Bool
    public var timeFormat: TimeFormat
    public var showsDate: Bool
    public var dateFormat: DateFormat

    public init(
        isShown: Bool = false, showsSeconds: Bool = false, timeFormat: TimeFormat = .system,
        showsDate: Bool = false, dateFormat: DateFormat = .system
    ) {
        self.isShown = isShown
        self.showsSeconds = showsSeconds
        self.timeFormat = timeFormat
        self.showsDate = showsDate
        self.dateFormat = dateFormat
    }
}

/// 2026-12-28 22:58:58 UTC: two digits everywhere it can have them, so the text measured on it is the widest the clock shows.
public let clockWidestDate = Date(timeIntervalSince1970: 1798498738)

private func timeText(date: Date, settings: ClockSettings, locale: Locale, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    let seconds = settings.showsSeconds ? ":ss" : ""
    switch settings.timeFormat {
    case .system: formatter.timeStyle = settings.showsSeconds ? .medium : .short
    case .twelveHour: formatter.dateFormat = "h:mm\(seconds) a"
    case .twentyFourHour: formatter.dateFormat = "HH:mm\(seconds)"
    }
    return formatter.string(from: date)
}

private func dateText(date: Date, format: DateFormat, locale: Locale, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    switch format {
    case .system:
        formatter.locale = locale
        formatter.dateStyle = .short
    case .iso, .dayMonthYear:
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format == .iso ? "yyyy-MM-dd" : "dd/MM/yyyy"
    }
    return formatter.string(from: date)
}

public func clockText(
    date: Date, settings: ClockSettings, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent
) -> (time: String, date: String?) {
    (
        timeText(date: date, settings: settings, locale: locale, timeZone: timeZone),
        settings.showsDate ? dateText(date: date, format: settings.dateFormat, locale: locale, timeZone: timeZone) : nil
    )
}

/// Spells the date out, whatever its display format: VoiceOver reads 2026-11-04 digit by digit.
public func clockAccessibilityLabel(
    date: Date, settings: ClockSettings, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent
) -> String {
    let time = timeText(date: date, settings: settings, locale: locale, timeZone: timeZone)
    guard settings.showsDate else { return time }
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.dateStyle = .full
    return "\(time), \(formatter.string(from: date))"
}

/// The next time the clock's text changes, strictly after `date`.
public func nextClockTick(after date: Date, showsSeconds: Bool) -> Date {
    let period: TimeInterval = showsSeconds ? 1 : 60
    return Date(timeIntervalSince1970: ((date.timeIntervalSince1970 / period).rounded(.down) + 1) * period)
}
