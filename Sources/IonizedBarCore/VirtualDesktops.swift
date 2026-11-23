import CoreGraphics

/// Which virtual desktop each window is on. Memory only: AX elements don't survive a restart.
public struct VirtualDesktops<Key: Hashable> {
    public static var maxCount: Int { 8 }

    public private(set) var count: Int
    public private(set) var current = 1
    private var desktops: [Key: Int] = [:]
    private var lastFocused: Key?
    /// Raised when switching back, as switching otherwise leaves the focus on a parked window.
    private var lastFocusedByDesktop: [Int: Key] = [:]

    public init(count: Int) {
        self.count = min(max(count, 1), Self.maxCount)
    }

    /// New windows go to the current desktop, and windows neither seen nor alive are forgotten. Returns the new ones.
    @discardableResult
    public mutating func update(seen: [Key], alive: Set<Key>) -> Set<Key> {
        let listed = Set(seen)
        desktops = desktops.filter { listed.contains($0.key) || alive.contains($0.key) }
        lastFocusedByDesktop = lastFocusedByDesktop.filter { desktops[$0.value] != nil }
        var new: Set<Key> = []
        for key in seen where desktops[key] == nil {
            desktops[key] = current
            new.insert(key)
        }
        return new
    }

    public func desktop(of key: Key) -> Int? { desktops[key] }

    /// A window not seen yet will open on the current desktop.
    public func isOnCurrent(_ key: Key) -> Bool { (desktops[key] ?? current) == current }

    /// Switches to the window's desktop when Cmd-Tab, Mission Control or a notification focused a window of another one.
    /// Only on a change of focus: switching away leaves the focus on a window that is about to be parked. True if it switched.
    @discardableResult
    public mutating func focus(_ key: Key) -> Bool {
        defer { lastFocused = key }
        guard let desktop = desktops[key] else { return false }
        lastFocusedByDesktop[desktop] = key
        guard key != lastFocused, desktop != current else { return false }
        current = desktop
        return true
    }

    /// The window last focused on `desktop`, if it is still there: it can have been moved since.
    public func windowToRaise(on desktop: Int) -> Key? {
        guard let key = lastFocusedByDesktop[desktop], desktops[key] == desktop else { return nil }
        return key
    }

    public mutating func switchTo(_ desktop: Int) {
        guard (1...count).contains(desktop) else { return }
        current = desktop
    }

    public mutating func move(_ key: Key, to desktop: Int) {
        guard (1...count).contains(desktop), desktops[key] != nil else { return }
        desktops[key] = desktop
    }

    /// Windows of the removed desktops go to the new last one, as in KDE.
    public mutating func setCount(_ newCount: Int) {
        count = min(max(newCount, 1), Self.maxCount)
        current = min(current, count)
        desktops = desktops.mapValues { min($0, count) }
    }
}

public enum Placement: Equatable {
    case show, park, bringBack, stayHidden
}

/// What to do with a window on a snapshot. A window that can't be parked, minimized or fullscreen, only leaves the bar.
public func placement(isOnCurrent: Bool, isParked: Bool, canPark: Bool) -> Placement {
    switch (isOnCurrent, isParked) {
    case (true, false): .show
    case (true, true): .bringBack
    case (false, true): .stayHidden
    case (false, false): canPark ? .park : .stayHidden
    }
}

/// macOS keeps this much of a window's height on screen, whatever position it is given (measured on macOS 27.2).
public let parkedVisibleHeight: CGFloat = 32

/// Where to hide a window of `size` on `screen`, in AX coordinates: its bottom corner, with 1 pt of its width left on
/// screen, behind the bar. Asking for more lets macOS pull it back 40 pt. The right corner unless the window would then
/// overlap another display, where macOS would move it fully onto that display.
public func parkingOrigin(size: CGSize, screen: CGRect, otherScreens: [CGRect]) -> CGPoint {
    let right = CGPoint(x: screen.maxX - 1, y: screen.maxY - 1)
    let left = CGPoint(x: screen.minX - size.width + 1, y: screen.maxY - 1)
    func isClear(_ origin: CGPoint) -> Bool {
        // Where macOS actually leaves it.
        let parked = CGRect(x: origin.x, y: screen.maxY - parkedVisibleHeight, width: size.width, height: size.height)
        return !otherScreens.contains { $0.intersects(parked) }
    }
    return isClear(right) || !isClear(left) ? right : left
}

/// A window left parked by a crash or a kill: no more than 1 pt of its width is on any display.
public func isParked(_ frame: CGRect, screens: [CGRect]) -> Bool {
    let widths = screens.map { $0.intersection(frame) }.filter { !$0.isNull }.map(\.width)
    return !widths.isEmpty && widths.allSatisfy { $0 <= 1 }
}

/// Where to bring back a window found parked, in AX coordinates: centred on its display, its top-left kept on it.
public func recoveredOrigin(size: CGSize, screen: CGRect) -> CGPoint {
    CGPoint(x: max(screen.minX, screen.midX - size.width / 2), y: max(screen.minY, screen.midY - size.height / 2))
}

/// The pager's grid: one row for two desktops, two rows from three on.
public func pagerGrid(count: Int) -> (rows: Int, columns: Int) {
    let rows = count > 2 ? 2 : 1
    return (rows, (count + rows - 1) / rows)
}
