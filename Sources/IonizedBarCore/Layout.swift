import CoreGraphics

public struct Display: Sendable, Equatable {
    public let id: UInt32
    public let frame: CGRect

    public init(id: UInt32, frame: CGRect) {
        self.id = id
        self.frame = frame
    }
}

public struct EntryWidth: Equatable {
    public let width: CGFloat
    public let isIconOnly: Bool

    public init(width: CGFloat, isIconOnly: Bool) {
        self.width = width
        self.isIconOnly = isIconOnly
    }
}

public struct OnScreenWindow: Sendable {
    public let pid: Int32
    public let bounds: CGRect

    public init(pid: Int32, bounds: CGRect) {
        self.pid = pid
        self.bounds = bounds
    }
}

public func flipRect(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: primaryScreenHeight - rect.minY - rect.height, width: rect.width, height: rect.height)
}

public func assignDisplay(windowFrame: CGRect, displays: [Display]) -> Display? {
    var best: (display: Display, area: CGFloat)?
    for display in displays {
        let overlap = display.frame.intersection(windowFrame)
        let area = overlap.isNull ? 0 : overlap.width * overlap.height
        if area > (best?.area ?? 0) { best = (display, area) }
    }
    return best?.display
}

public func entryWidth(
    barWidth: CGFloat, entryCount: Int, maxWidth: CGFloat = 220, iconOnlyBelow: CGFloat = 48
) -> EntryWidth {
    guard entryCount > 0 else { return EntryWidth(width: 0, isIconOnly: false) }
    let width = min(maxWidth, barWidth / CGFloat(entryCount))
    return EntryWidth(width: width, isIconOnly: width < iconOnlyBelow)
}

public func isRealWindow(subrole: String?, isMinimized: Bool, isAppHidden: Bool) -> Bool {
    // AppKit reports AXDialog for a standard window while it is minimized or its app hidden (macOS 27.2).
    subrole == "AXStandardWindow" || ((isMinimized || isAppHidden) && subrole == "AXDialog")
}

public func isOnCurrentSpace(pid: Int32, frame: CGRect, isMinimized: Bool, isAppHidden: Bool, onScreen: [OnScreenWindow]) -> Bool {
    if isMinimized || isAppHidden { return true }
    return onScreen.contains { window in
        window.pid == pid
            && abs(window.bounds.minX - frame.minX) <= 2
            && abs(window.bounds.minY - frame.minY) <= 2
            && abs(window.bounds.maxX - frame.maxX) <= 2
            && abs(window.bounds.maxY - frame.maxY) <= 2
    }
}

public func barFrame(screenFrame: CGRect, height: CGFloat = 36) -> CGRect {
    CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: height)
}

/// Cocoa coordinates (bottom-left origin), like `barFrame`.
public func overlapsBar(_ window: CGRect, bar: CGRect) -> Bool {
    let overlap = window.intersection(bar)
    return !overlap.isNull && overlap.width > 0 && overlap.height > 0
}

/// Cocoa coordinates. The room is from the bar's top to `visibleFrame`'s top (below the menu bar); x and width never change.
public func pushedFrame(_ window: CGRect, screenFrame: CGRect, visibleFrame: CGRect, barHeight: CGFloat) -> CGRect {
    let bottom = screenFrame.minY + barHeight
    let room = visibleFrame.maxY - bottom
    let height = min(window.height, room)
    let y = min(max(window.minY, bottom), visibleFrame.maxY - height)
    return CGRect(x: window.minX, y: y, width: window.width, height: height)
}

public enum EntryClickAction {
    case raise, minimize, restore
}

public func clickAction(isActive: Bool, isMinimized: Bool) -> EntryClickAction {
    if isMinimized { return .restore }
    return isActive ? .minimize : .raise
}

public func entryAccessibilityLabel(title: String, appName: String, isActive: Bool, isMinimized: Bool) -> String {
    let name = title.isEmpty ? appName : "\(title), \(appName)"
    if isMinimized { return "\(name), minimized" }
    return isActive ? "\(name), active" : name
}

public func groupAccessibilityLabel(appName: String, windowCount: Int, isActive: Bool, isMinimized: Bool) -> String {
    entryAccessibilityLabel(title: "", appName: "\(appName), \(windowCount) windows", isActive: isActive, isMinimized: isMinimized)
}

public enum GroupingMode: String, CaseIterable, Sendable {
    case never, whenFull, always
}

public enum BarItem<Window> {
    case window(Window)
    case group(pid: Int32, windows: [Window])

    public var windows: [Window] {
        switch self {
        case .window(let window): [window]
        case .group(_, let windows): windows
        }
    }
}

public func appsToGroup(
    windowCounts: [(pid: Int32, count: Int)], barWidth: CGFloat, mode: GroupingMode, minEntryWidth: CGFloat
) -> Set<Int32> {
    let candidates = windowCounts.enumerated().filter { $0.element.count > 1 }
    switch mode {
    case .never:
        return []
    case .always:
        return Set(candidates.map(\.element.pid))
    case .whenFull:
        var entryCount = windowCounts.reduce(0) { $0 + $1.count }
        var grouped: Set<Int32> = []
        // Most windows first; on a tie the later app, so the apps at the start of the bar stay put.
        for candidate in candidates.sorted(by: { ($0.element.count, $0.offset) > ($1.element.count, $1.offset) }) {
            guard barWidth / CGFloat(entryCount) < minEntryWidth else { break }
            grouped.insert(candidate.element.pid)
            entryCount -= candidate.element.count - 1
        }
        return grouped
    }
}

public func barItems<Window>(
    _ windows: [Window], pid: (Window) -> Int32, barWidth: CGFloat, mode: GroupingMode, minEntryWidth: CGFloat
) -> [BarItem<Window>] {
    let windowsByPid = Dictionary(grouping: windows, by: pid)
    var counted: Set<Int32> = []
    let counts = windows.map(pid).filter { counted.insert($0).inserted }.map { (pid: $0, count: windowsByPid[$0]!.count) }
    let grouped = appsToGroup(windowCounts: counts, barWidth: barWidth, mode: mode, minEntryWidth: minEntryWidth)
    var placed: Set<Int32> = []
    return windows.compactMap { window in
        let windowPid = pid(window)
        guard grouped.contains(windowPid) else { return .window(window) }
        return placed.insert(windowPid).inserted ? .group(pid: windowPid, windows: windowsByPid[windowPid]!) : nil
    }
}
