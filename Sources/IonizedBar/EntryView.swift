import AppKit
import IonizedBarCore

struct EntryActions {
    let raise: (TrackedWindow) -> Void
    let minimize: (TrackedWindow) -> Void
    let restore: (TrackedWindow) -> Void
    let close: (TrackedWindow) -> Void
    let openSettings: @MainActor () -> Void
}

final class EntryView: NSView {
    private static let padding: CGFloat = 8
    private static let iconSize: CGFloat = 16
    private static let countGap: CGFloat = 2

    private let actions: EntryActions
    private var item: BarItem<TrackedWindow>
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private var isActive = false { didSet { needsDisplay = true } }
    private var isHovered = false { didSet { needsDisplay = true } }
    private var display = TaskDisplay.content
    var isIconOnly = false {
        didSet {
            guard isIconOnly != oldValue else { return }
            updateText()
            needsLayout = true
        }
    }

    init(item: BarItem<TrackedWindow>, actions: EntryActions) {
        self.item = item
        self.actions = actions
        super.init(frame: .zero)
        icon.image = NSRunningApplication(processIdentifier: item.windows[0].pid)?.icon
        title.lineBreakMode = .byTruncatingTail
        addSubview(icon)
        addSubview(title)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        icon.setAccessibilityElement(false)
        title.setAccessibilityElement(false)
        // activeAlways: this app is never the active one, and inVisibleRect follows resizes.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func updateText() {
        switch item {
        case .window(let window):
            let isTitleShown = display == .content && !isIconOnly
            title.stringValue = display == .content ? window.title : window.appName
            title.isHidden = isIconOnly
            toolTip = isTitleShown ? nil : window.title
        case .group(_, let windows):
            let label = "\(windows[0].appName) (\(windows.count))"
            title.stringValue = isIconOnly ? String(windows.count) : label
            title.isHidden = false
            toolTip = isIconOnly ? label : nil
        }
    }

    private var accessibilityText: String {
        let windows = item.windows
        let name = switch item {
        case .window(let window): "\(window.appName), \(window.title)"
        case .group: "\(windows[0].appName), \(windows.count) windows"
        }
        if isActive { return "\(name), active" }
        return windows.allSatisfy(\.isMinimized) ? "\(name), minimized" : name
    }

    func update(with item: BarItem<TrackedWindow>, display: TaskDisplay) {
        self.item = item
        self.display = display
        updateText()
        let windows = item.windows
        let isMinimized = windows.allSatisfy(\.isMinimized)
        isActive = windows.contains(where: \.isFocused)
        setAccessibilityLabel(accessibilityText)
        icon.alphaValue = isMinimized ? 0.5 : 1
        let font = NSFont.systemFont(ofSize: 13)
        title.font = isMinimized ? NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) : font
        title.textColor = isActive ? .alternateSelectedControlTextColor : isMinimized ? .secondaryLabelColor : .labelColor
        needsLayout = true
    }

    override func layout() {
        super.layout()
        // A group that lost its name shows its count beside the icon, so the pair is centered.
        let isCountShown = isIconOnly && !title.isHidden
        let gap = isCountShown ? Self.countGap : Self.padding
        let contentWidth = isCountShown ? Self.iconSize + gap + title.intrinsicContentSize.width : Self.iconSize
        // Rounded: an integer point is on a device pixel at every scale, so the icon and text stay sharp.
        let iconX = isIconOnly ? max(0, ((bounds.width - contentWidth) / 2).rounded()) : Self.padding
        icon.frame = CGRect(x: iconX, y: ((bounds.height - Self.iconSize) / 2).rounded(), width: Self.iconSize, height: Self.iconSize)
        let titleX = icon.frame.maxX + gap
        let titleSize = title.intrinsicContentSize
        let titleWidth = isCountShown ? titleSize.width : max(0, bounds.width - titleX - Self.padding)
        title.frame = CGRect(x: titleX, y: ((bounds.height - titleSize.height) / 2).rounded(), width: titleWidth, height: titleSize.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isActive || isHovered else { return }
        (isActive ? NSColor.controlAccentColor : NSColor.labelColor.withAlphaComponent(0.1)).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    // Keeps the icon and title out of event dispatch: a control-click on the title opens no menu otherwise.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseUp(with event: NSEvent) {
        // A control-click opens the menu: its mouse-up is not a click.
        if isInside(event) && !event.modifierFlags.contains(.control) { performClickAction() }
    }

    override func otherMouseUp(with event: NSEvent) {
        // A group ignores it, so a stray click can't close several windows.
        if event.buttonNumber == 2 && isInside(event), case .window(let window) = item { actions.close(window) }
    }

    override func accessibilityPerformPress() -> Bool {
        performClickAction()
        return true
    }

    override func menu(for event: NSEvent) -> NSMenu? { contextMenu() }

    private func isInside(_ event: NSEvent) -> Bool {
        bounds.contains(convert(event.locationInWindow, from: nil))
    }

    func performClickAction() {
        switch item {
        case .window(let window):
            switch clickAction(isActive: window.isFocused, isMinimized: window.isMinimized) {
            case .raise: actions.raise(window)
            case .minimize: actions.minimize(window)
            case .restore: actions.restore(window)
            }
        case .group(_, let windows):
            let menu = windowList(windows)
            // popUp places the menu's top-left at this point, so this puts the whole menu above the entry.
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + menu.size.height), in: self)
        }
    }

    func windowList(_ windows: [TrackedWindow]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for window in windows {
            let name = window.title.isEmpty ? window.appName : window.title
            let row = menu.addItem(withTitle: window.isMinimized ? "\(name) (minimized)" : name, action: #selector(pickWindow), keyEquivalent: "")
            row.target = self
            row.representedObject = window
            row.state = window.isFocused ? .on : .off
        }
        return menu
    }

    func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let appName = item.windows[0].appName
        switch item {
        case .window(let window):
            menu.addItem(withTitle: "Close", action: #selector(closeWindows), keyEquivalent: "")
            menu.addItem(withTitle: "Minimize", action: #selector(minimizeWindow), keyEquivalent: "").isEnabled = !window.isMinimized
        case .group:
            menu.addItem(withTitle: "Close All Windows", action: #selector(closeWindows), keyEquivalent: "")
        }
        menu.addItem(withTitle: "Quit \(appName)", action: #selector(quitApp), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        menu.addItem(withTitle: "Quit IonizedBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "").target = NSApp
        return menu
    }

    @objc private func pickWindow(_ sender: NSMenuItem) {
        guard let window = sender.representedObject as? TrackedWindow else { return }
        if window.isMinimized { actions.restore(window) } else { actions.raise(window) }
    }

    @objc private func openSettings() { actions.openSettings() }
    @objc private func closeWindows() { item.windows.forEach(actions.close) }
    @objc private func minimizeWindow() { item.windows.forEach(actions.minimize) }
    @objc private func quitApp() { NSRunningApplication(processIdentifier: item.windows[0].pid)?.terminate() }
}
