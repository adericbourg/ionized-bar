import Foundation

public struct InstalledApp: Sendable, Equatable {
    public let name: String
    public let url: URL
    public let category: AppCategory

    public init(name: String, url: URL, category: AppCategory = .other) {
        self.name = name
        self.url = url
        self.category = category
    }
}

/// The launcher's groups, in sidebar order. macOS's own categories are too many and too fine: most hold an app or two.
public enum AppCategory: String, CaseIterable, Sendable {
    case development = "Development"
    case education = "Education"
    case games = "Games"
    case graphics = "Graphics"
    case internet = "Internet"
    case multimedia = "Multimedia"
    case office = "Office"
    case utilities = "Utilities"
    case other = "Other"

    /// From an `LSApplicationCategoryType` value, which is optional: a quarter of the apps have none.
    public init(categoryType: String?) {
        switch categoryType?.replacing("public.app-category.", with: "") {
        case "developer-tools": self = .development
        case "education", "reference", "books": self = .education
        case "graphics-design", "photography": self = .graphics
        case "social-networking", "news": self = .internet
        case "music", "video", "entertainment": self = .multimedia
        case "productivity", "business", "finance": self = .office
        case "utilities": self = .utilities
        case let name? where name == "games" || name.hasSuffix("-games"): self = .games
        default: self = .other
        }
    }
}

/// What the launcher's sidebar selects.
public enum LauncherView: Equatable, Sendable {
    case favorites
    case all
    case category(AppCategory)

    public var title: String {
        switch self {
        case .favorites: "Favorites"
        case .all: "All Applications"
        case .category(let category): category.rawValue
        }
    }
}

/// The `.app` bundles directly in each folder and in its `Utilities` subfolder (`/System/Applications/Utilities`
/// holds Terminal, Activity Monitor...), sorted by name. Blocking: call it off the main thread.
public func listApplications(in folders: [URL]) -> [InstalledApp] {
    let fileManager = FileManager.default
    var apps: [InstalledApp] = []
    for folder in folders {
        for directory in [folder, folder.appendingPathComponent("Utilities")] {
            let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
            for url in urls where url.pathExtension == "app" {
                apps.append(InstalledApp(name: url.deletingPathExtension().lastPathComponent, url: url, category: declaredCategory(ofBundleAt: url)))
            }
        }
    }
    return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

private func declaredCategory(ofBundleAt url: URL) -> AppCategory {
    let data = try? Data(contentsOf: url.appendingPathComponent("Contents/Info.plist"))
    let plist = data.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: Any]
    return AppCategory(categoryType: plist?["LSApplicationCategoryType"] as? String)
}

/// The items matching `query` against their name, best first: exact, prefix, word prefix, substring, one or two
/// typos (a wrong, missing, extra or swapped letter, from 4 characters), then scattered letters. An empty query
/// keeps everything in the given order.
public func fuzzyFilter<T>(_ items: [T], query: String, name: (T) -> String) -> [T] {
    let q = fold(query)
    if q.isEmpty { return items }
    let ranked: [(item: T, tier: Int, name: String)] = items.compactMap { item in
        let n = name(item)
        return tier(of: q, in: fold(n)).map { (item, $0, n) }
    }
    return ranked.sorted {
        ($0.tier, $0.name.count, $0.name) < ($1.tier, $1.name.count, $1.name)
    }.map(\.item)
}

private func fold(_ s: String) -> [Character] {
    Array(s.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))
}

private func tier(of q: [Character], in n: [Character]) -> Int? {
    if q == n { return 0 }
    if n.starts(with: q) { return 1 }
    let wordStarts = n.indices.filter { $0 == 0 || !n[$0 - 1].isLetter && !n[$0 - 1].isNumber }
    if wordStarts.contains(where: { n[$0...].starts(with: q) }) { return 2 }
    if n.indices.contains(where: { n[$0...].starts(with: q) }) { return 3 }
    let maxTypos = q.count >= 8 ? 2 : q.count >= 4 ? 1 : 0
    if maxTypos > 0, wordStarts.contains(where: { start in
        (max(1, q.count - maxTypos)...(q.count + maxTypos)).contains { length in
            start + length <= n.count && editDistance(q, Array(n[start..<start + length])) <= maxTypos
        }
    }) { return 4 }
    var rest = q[...]
    for c in n where c == rest.first { rest = rest.dropFirst() }
    return rest.isEmpty ? 5 : nil
}

/// What the launcher panel shows: the apps matching the query, and the row Up, Down and Return act on.
public struct LauncherList {
    public static let noMatchMessage = "No applications found"
    public static let noFavoritesMessage = "No favorites yet. Right-click a task on the bar and choose Pin."

    private var apps: [InstalledApp] = []
    private var favorites: [InstalledApp] = []
    public private(set) var view = LauncherView.all
    public private(set) var query = ""
    public private(set) var rows: [InstalledApp] = []
    public private(set) var selectedIndex: Int?

    public init() {}

    public var selected: InstalledApp? { selectedIndex.map { rows[$0] } }

    /// A search that found nothing, not a list that isn't read yet.
    public var hasNoMatch: Bool { rows.isEmpty && !query.isEmpty }

    /// Focus stays in the search field, so VoiceOver reads neither the rows nor the selection on its own.
    public var resultsAnnouncement: String {
        guard let selected else { return hasNoFavorites ? Self.noFavoritesMessage : Self.noMatchMessage }
        return "\(rows.count) application\(rows.count == 1 ? "" : "s"), \(selected.name) selected"
    }

    /// A fresh read keeps the selected app, by URL: names repeat across folders.
    public mutating func setApps(_ apps: [InstalledApp]) {
        let maybeSelectedURL = selected?.url
        self.apps = apps
        if !sidebarItems.contains(view) { view = .all }
        refreshRows()
        selectedIndex = rows.firstIndex { $0.url == maybeSelectedURL } ?? (rows.isEmpty ? nil : 0)
    }

    public mutating func setQuery(_ query: String) {
        self.query = query
        refreshRows()
        selectedIndex = rows.isEmpty ? nil : 0
    }

    public mutating func moveSelection(by offset: Int) {
        guard let selectedIndex else { return }
        self.selectedIndex = min(max(selectedIndex + offset, 0), rows.count - 1)
    }

    /// The two fixed views, then the groups that have apps.
    public var sidebarItems: [LauncherView] {
        let present = Set(apps.map(\.category))
        return [.favorites, .all] + AppCategory.allCases.filter(present.contains).map(LauncherView.category)
    }

    /// A search always shows a list, whichever view it started from.
    public var showsGrid: Bool { view == .favorites && query.isEmpty }

    public var hasNoFavorites: Bool { rows.isEmpty && showsGrid }

    /// What each opening starts from: Favorites, unless that would be empty.
    public mutating func reset(favorites: [InstalledApp]) {
        self.favorites = favorites
        setView(favorites.isEmpty ? .all : .favorites)
    }

    /// Picking a view ends a search.
    public mutating func setView(_ view: LauncherView) {
        self.view = view
        setQuery("")
    }

    /// Off the rows, as for a pointer over no row, the selection stays: it is what Return opens.
    public mutating func select(index: Int) {
        if rows.indices.contains(index) { selectedIndex = index }
    }

    /// Up from the first row stays. Down keeps the column, or goes to the last item when the row below is shorter.
    public mutating func moveGridSelection(byRows rowOffset: Int, columns: Int) {
        guard let selectedIndex else { return }
        let target = selectedIndex + rowOffset * columns
        if target < 0 { return }
        let hasRowBelow = selectedIndex / columns < (rows.count - 1) / columns
        if target < rows.count {
            self.selectedIndex = target
        } else if hasRowBelow {
            self.selectedIndex = rows.count - 1
        }
    }

    private mutating func refreshRows() {
        if !query.isEmpty {
            rows = fuzzyFilter(apps, query: query, name: \.name)
            return
        }
        switch view {
        case .favorites: rows = favorites
        case .all: rows = apps
        case .category(let category): rows = apps.filter { $0.category == category }
        }
    }
}

/// Optimal string alignment distance: insertion, deletion, substitution and adjacent swap each cost 1.
private func editDistance(_ a: [Character], _ b: [Character]) -> Int {
    var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in 0...a.count { d[i][0] = i }
    for j in 0...b.count { d[0][j] = j }
    guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
    for i in 1...a.count {
        for j in 1...b.count {
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
            }
        }
    }
    return d[a.count][b.count]
}
