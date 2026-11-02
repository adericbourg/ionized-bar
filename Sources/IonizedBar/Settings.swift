import Foundation
import IonizedBarCore

enum TaskDisplay: String, CaseIterable {
    case iconOnly, appName, content
}

struct Settings {
    private static let groupingKey = "grouping"
    private static let taskDisplayKey = "taskDisplay"
    private static let showsPreviewsKey = "showsPreviews"

    var grouping: GroupingMode
    var taskDisplay: TaskDisplay
    var showsPreviews = false

    static func load() -> Settings {
        let defaults = UserDefaults.standard
        return Settings(
            grouping: GroupingMode(rawValue: defaults.string(forKey: groupingKey) ?? "") ?? .never,
            taskDisplay: TaskDisplay(rawValue: defaults.string(forKey: taskDisplayKey) ?? "") ?? .content,
            showsPreviews: defaults.bool(forKey: showsPreviewsKey)
        )
    }

    func save() {
        UserDefaults.standard.set(grouping.rawValue, forKey: Self.groupingKey)
        UserDefaults.standard.set(taskDisplay.rawValue, forKey: Self.taskDisplayKey)
        UserDefaults.standard.set(showsPreviews, forKey: Self.showsPreviewsKey)
    }
}
