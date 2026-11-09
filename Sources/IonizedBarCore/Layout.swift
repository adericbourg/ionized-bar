import CoreGraphics
import Foundation

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

public struct CaptureCandidate: Sendable {
    public let id: UInt32
    public let pid: Int32
    public let bounds: CGRect

    public init(id: UInt32, pid: Int32, bounds: CGRect) {
        self.id = id
        self.pid = pid
        self.bounds = bounds
    }
}

/// The window id of the only candidate of `pid` whose bounds are within 2pt of `frame`; nil when none or several match.
public func matchWindow(pid: Int32, frame: CGRect, candidates: [CaptureCandidate]) -> UInt32? {
    let matches = candidates.filter { $0.pid == pid && framesMatch($0.bounds, frame) }
    return matches.count == 1 ? matches[0].id : nil
}

/// Centered above `entry` and kept on `screen`, all in Cocoa coordinates.
public func previewFrame(entry: CGRect, size: CGSize, screen: CGRect, gap: CGFloat) -> CGRect {
    let x = min(max(entry.midX - size.width / 2, screen.minX + gap), screen.maxX - size.width - gap)
    return CGRect(x: x.rounded(), y: (entry.maxY + gap).rounded(), width: size.width, height: size.height)
}

/// Above `button`, kept on `screen` (its visible frame), and no larger than the room there.
public func launcherFrame(button: CGRect, size: CGSize, screen: CGRect, gap: CGFloat) -> CGRect {
    let fitted = CGSize(width: min(size.width, screen.width - 2 * gap), height: min(size.height, screen.maxY - button.maxY - 2 * gap))
    return previewFrame(entry: button, size: fitted, screen: screen, gap: gap)
}

/// Whether `point` is in the strip between `entry` and the `panel` above it, within the panel's width.
public func isInPreviewGap(_ point: CGPoint, entry: CGRect, panel: CGRect) -> Bool {
    point.y >= entry.maxY && point.y < panel.minY && (panel.minX..<panel.maxX).contains(point.x)
}

/// `size` scaled down to fit `box`, keeping its proportions. Never scaled up.
public func fittedSize(_ size: CGSize, within box: CGSize) -> CGSize {
    let scale = min(1, box.width / size.width, box.height / size.height)
    return CGSize(width: size.width * scale, height: size.height * scale)
}

/// Both frames are in top-left-origin coordinates (AX and CG/ScreenCaptureKit agree).
func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2 && abs(a.maxX - b.maxX) <= 2 && abs(a.maxY - b.maxY) <= 2
}

public func flipRect(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: primaryScreenHeight - rect.minY - rect.height, width: rect.width, height: rect.height)
}

public func assignDisplay(windowFrame: CGRect, displays: [Display]) -> Display? {
    var best: (display: Display, area: CGFloat)?
    for display in displays {
        let overlap = display.frame.intersection(windowFrame)
        let area = overlap.width * overlap.height
        if area > (best?.area ?? 0) { best = (display, area) }
    }
    return best?.display
}

public func entryWidth(barWidth: CGFloat, entryCount: Int, maxWidth: CGFloat = 220) -> EntryWidth {
    guard entryCount > 0 else { return EntryWidth(width: 0, isIconOnly: false) }
    let width = min(maxWidth, barWidth / CGFloat(entryCount))
    return EntryWidth(width: width, isIconOnly: width < 48)
}

public let launcherWidth: CGFloat = 48
public let pinnedIconWidth: CGFloat = 36

/// Where a bar's tasks start and the width they share: what's left after the launcher, the pinned icons after it, and the clock at the far end.
public func taskSlot(barWidth: CGFloat, pinnedWidth: CGFloat = 0, clockWidth: CGFloat = 0) -> (x: CGFloat, width: CGFloat) {
    let x = launcherWidth + pinnedWidth
    return (x, max(0, barWidth - x - clockWidth))
}

public func isRealWindow(subrole: String?, isMinimized: Bool, isAppHidden: Bool) -> Bool {
    // AppKit reports AXDialog for a standard window while it is minimized or its app hidden (macOS 27.2).
    subrole == "AXStandardWindow" || ((isMinimized || isAppHidden) && subrole == "AXDialog")
}

/// Pushed off the bar, even when not a taskbar entry. Chrome's "is sharing a window" bar reports AXUnknown.
public func isPushable(subrole: String?) -> Bool {
    subrole == "AXStandardWindow" || subrole == "AXUnknown"
}

public func isOnCurrentSpace(pid: Int32, frame: CGRect, isMinimized: Bool, isAppHidden: Bool, onScreen: [OnScreenWindow]) -> Bool {
    if isMinimized || isAppHidden { return true }
    return onScreen.contains { window in
        window.pid == pid && framesMatch(window.bounds, frame)
    }
}

public func barFrame(screenFrame: CGRect, height: CGFloat = 36) -> CGRect {
    CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: height)
}

/// Cocoa coordinates (bottom-left origin), like `barFrame`.
public func overlapsBar(_ window: CGRect, bar: CGRect) -> Bool {
    // `intersects` alone is true for an empty rect inside the bar.
    !window.isEmpty && window.intersects(bar)
}

/// Cocoa coordinates. The room is from the bar's top to `visibleFrame`'s top (below the menu bar); x and width never change.
public func pushedFrame(_ window: CGRect, screenFrame: CGRect, visibleFrame: CGRect, barHeight: CGFloat) -> CGRect {
    let bottom = screenFrame.minY + barHeight
    let room = visibleFrame.maxY - bottom
    let height = min(window.height, room)
    let y = min(max(window.minY, bottom), visibleFrame.maxY - height)
    return CGRect(x: window.minX, y: y, width: window.width, height: height)
}

/// Cocoa coordinates. Nil when the window must not be pushed, including when there is no room above the bar.
public func pushTarget(
    _ window: CGRect, isMinimized: Bool, isFullScreen: Bool, screenFrame: CGRect, visibleFrame: CGRect, barHeight: CGFloat = 36
) -> CGRect? {
    let bar = barFrame(screenFrame: screenFrame, height: barHeight)
    guard !isMinimized, !isFullScreen, overlapsBar(window, bar: bar), visibleFrame.maxY > bar.maxY else { return nil }
    return pushedFrame(window, screenFrame: screenFrame, visibleFrame: visibleFrame, barHeight: barHeight)
}

public enum PushVerdict: Equatable {
    case idle, wait, push
}

/// One window's push state, stepped on each snapshot and timer tick.
public struct PushMemory: Sendable {
    public static let settleTime: TimeInterval = 0.3
    /// How long the frame must hold after a push before it counts as where the push ended.
    /// ponytail: an app repositioning itself later than this fights back at this period; add a per-window backoff if one shows up.
    public static let resultSettleTime: TimeInterval = 1

    public private(set) var lastSeen: TimeInterval
    public private(set) var isAwaitingResult = false
    private var frame: CGRect?
    private var frameSince: TimeInterval
    private var endedAt: CGRect?

    public init(now: TimeInterval) {
        lastSeen = now
        frameSince = now
    }

    public mutating func step(frame: CGRect, wantsPush: Bool, isMouseDown: Bool, now: TimeInterval) -> PushVerdict {
        lastSeen = now
        if frame != self.frame {
            self.frame = frame
            frameSince = now
            endedAt = nil
        }
        if !isAwaitingResult && (!wantsPush || endedAt == frame) { return .idle }
        if isMouseDown || now - frameSince < (isAwaitingResult ? Self.resultSettleTime : Self.settleTime) { return .wait }
        if isAwaitingResult {
            isAwaitingResult = false
            endedAt = frame
            return .idle
        }
        isAwaitingResult = true
        frameSince = now
        return .push
    }

    /// The push never happened, so whatever frame comes next is not its result.
    public mutating func pushWasStale() {
        isAwaitingResult = false
    }
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
