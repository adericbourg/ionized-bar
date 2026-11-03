import CoreGraphics

/// The user-set order of tasks, as one relative order of all windows that each bar projects onto its own.
/// A move only changes the place of the windows it moves, and of the other windows of a group it passes,
/// so the other bars' windows and those away (another Space or display) stay put relative to everything
/// else, and come back to their place.
public struct TaskOrder<Key: Hashable> {
    public private(set) var keys: [Key] = []

    public init() {}

    /// `seen` is what the bars show, `alive` what wasn't destroyed: the rest of the order goes, new windows go last.
    /// `seen` counts as alive: a snapshot can still list a window just reported destroyed, and it must not jump.
    public mutating func update(seen: [Key], alive: Set<Key>) {
        let listed = Set(seen)
        keys.removeAll { !listed.contains($0) && !alive.contains($0) }
        var known = Set(keys)
        keys += seen.filter { known.insert($0).inserted }
    }

    public func sorted<Window>(_ windows: [Window], key: (Window) -> Key) -> [Window] {
        let ranks = Dictionary(keys.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        return windows.sorted { ranks[key($0), default: .max] < ranks[key($1), default: .max] }
    }

    /// Moves `items[from]` to index `to` of `items`, a bar's items built from `sorted`, clamped to its ends.
    public mutating func move<Window>(_ items: [BarItem<Window>], from: Int, to: Int, key: (Window) -> Key) {
        let to = min(max(to, 0), items.count - 1)
        guard items.indices.contains(from), to != from else { return }
        let mover = items[from].windows.map(key)
        let passed = items[to].windows.map(key)
        guard let anchor = passed.first else { return }
        let isMovingRight = to > from
        // A group sits at its first window, and other entries can sit between that and its last one.
        // Past a group, its other windows close up so that the mover lands right after the whole entry.
        let block = isMovingRight ? passed.dropFirst() + mover : mover
        // A window closed since `items` was built must not come back, and with no anchor there's nothing to land next to.
        // No anchor also covers an app listing a window twice as two entries, moved onto its own copy.
        guard block.allSatisfy(keys.contains) else { return }
        var rest = keys.filter { !block.contains($0) }
        guard let anchorIndex = rest.firstIndex(of: anchor) else { return }
        rest.insert(contentsOf: block, at: anchorIndex + (isMovingRight ? 1 : 0))
        keys = rest
    }
}

public func canMoveLeft(itemAt index: Int) -> Bool { index > 0 }

public func canMoveRight(itemAt index: Int, itemCount: Int) -> Bool { index < itemCount - 1 }

/// About 4pt from the press, in any direction: a smaller slip stays a click.
public func isPastDragThreshold(from start: CGPoint, to point: CGPoint) -> Bool {
    hypot(point.x - start.x, point.y - start.y) > 4
}

/// Under the pointer between the first and last slots: entries can stop short of the task area's end.
/// Past them it keeps following with growing resistance, and stays less than one entry width beyond.
/// `grabOffset` is capped so that the pointer stays on an entry that narrowed during the drag.
public func draggedEntryX(pointerX: CGFloat, grabOffset: CGFloat, slotX: CGFloat, entryWidth: CGFloat, entryCount: Int) -> CGFloat {
    let lastSlotX = slotX + CGFloat(max(entryCount - 1, 0)) * entryWidth
    let x = pointerX - min(grabOffset, entryWidth)
    // Slope 1 at the edge, so there's no jolt where the resistance starts.
    func stretch(_ overshoot: CGFloat) -> CGFloat { entryWidth * overshoot / (overshoot + entryWidth) }
    if x < slotX { return slotX - stretch(slotX - x) }
    if x > lastSlotX { return lastSlotX + stretch(x - lastSlotX) }
    return x
}

/// The slot nearest an entry at `entryX`. With no width to tell slots apart, the entry stays at `from`.
public func dragTargetIndex(entryX: CGFloat, from: Int, slotX: CGFloat, entryWidth: CGFloat, entryCount: Int) -> Int {
    guard entryWidth > 0, entryCount > 0 else { return from }
    return min(max(Int(((entryX - slotX) / entryWidth).rounded()), 0), entryCount - 1)
}
