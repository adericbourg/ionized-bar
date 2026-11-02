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
