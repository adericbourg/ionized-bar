import Foundation
import IonizedBarCore

enum TaskDisplay: String, CaseIterable {
    case iconOnly, appName, content
}

struct Settings {
    private static let groupingKey = "grouping"
    private static let taskDisplayKey = "taskDisplay"

    var grouping: GroupingMode
    var taskDisplay: TaskDisplay

    static func load() -> Settings {
        let defaults = UserDefaults.standard
        return Settings(
            grouping: GroupingMode(rawValue: defaults.string(forKey: groupingKey) ?? "") ?? .never,
            taskDisplay: TaskDisplay(rawValue: defaults.string(forKey: taskDisplayKey) ?? "") ?? .content
        )
    }

    func save() {
        UserDefaults.standard.set(grouping.rawValue, forKey: Self.groupingKey)
        UserDefaults.standard.set(taskDisplay.rawValue, forKey: Self.taskDisplayKey)
    }
}
