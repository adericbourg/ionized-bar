import Foundation
import IonizedBarCore

enum TaskDisplay: String, CaseIterable {
    case iconOnly, appName, content
}

struct Settings {
    private static let groupingKey = "grouping"
    private static let taskDisplayKey = "taskDisplay"
    private static let showsPreviewsKey = "showsPreviews"
    private static let keepsPinnedVisibleKey = "keepsPinnedVisible"
    private static let clockIsShownKey = "clockIsShown"
    private static let clockShowsSecondsKey = "clockShowsSeconds"
    private static let clockTimeFormatKey = "clockTimeFormat"
    private static let clockShowsDateKey = "clockShowsDate"
    private static let clockDateFormatKey = "clockDateFormat"

    var grouping: GroupingMode
    var taskDisplay: TaskDisplay
    var showsPreviews = false
    var keepsPinnedVisible = false
    var clock = ClockSettings()

    static func load() -> Settings {
        let defaults = UserDefaults.standard
        return Settings(
            grouping: GroupingMode(rawValue: defaults.string(forKey: groupingKey) ?? "") ?? .never,
            taskDisplay: TaskDisplay(rawValue: defaults.string(forKey: taskDisplayKey) ?? "") ?? .content,
            showsPreviews: defaults.bool(forKey: showsPreviewsKey),
            keepsPinnedVisible: defaults.bool(forKey: keepsPinnedVisibleKey),
            clock: ClockSettings(
                isShown: defaults.bool(forKey: clockIsShownKey),
                showsSeconds: defaults.bool(forKey: clockShowsSecondsKey),
                timeFormat: TimeFormat(rawValue: defaults.string(forKey: clockTimeFormatKey) ?? "") ?? .system,
                showsDate: defaults.bool(forKey: clockShowsDateKey),
                dateFormat: DateFormat(rawValue: defaults.string(forKey: clockDateFormatKey) ?? "") ?? .system
            )
        )
    }

    func save() {
        UserDefaults.standard.set(grouping.rawValue, forKey: Self.groupingKey)
        UserDefaults.standard.set(taskDisplay.rawValue, forKey: Self.taskDisplayKey)
        UserDefaults.standard.set(showsPreviews, forKey: Self.showsPreviewsKey)
        UserDefaults.standard.set(keepsPinnedVisible, forKey: Self.keepsPinnedVisibleKey)
        UserDefaults.standard.set(clock.isShown, forKey: Self.clockIsShownKey)
        UserDefaults.standard.set(clock.showsSeconds, forKey: Self.clockShowsSecondsKey)
        UserDefaults.standard.set(clock.timeFormat.rawValue, forKey: Self.clockTimeFormatKey)
        UserDefaults.standard.set(clock.showsDate, forKey: Self.clockShowsDateKey)
        UserDefaults.standard.set(clock.dateFormat.rawValue, forKey: Self.clockDateFormatKey)
    }
}
