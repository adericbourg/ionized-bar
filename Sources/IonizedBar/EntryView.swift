import AppKit
import IonizedBarCore

final class EntryView: BarButton {
    private static let padding: CGFloat = 8
    private static let iconSize: CGFloat = 16
    private static let countGap: CGFloat = 2

    private var item: BarItem<TrackedWindow>
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private(set) var isActive = false { didSet { needsDisplay = true } }
    private var display = TaskDisplay.content
    var isIconOnly = false {
        didSet {
            guard isIconOnly != oldValue else { return }
            updateText()
            needsLayout = true
        }
    }

    init(item: BarItem<TrackedWindow>, manager: BarManager) {
        self.item = item
        super.init(manager: manager)
        icon.image = NSRunningApplication(processIdentifier: item.windows[0].pid)?.icon
        title.lineBreakMode = .byTruncatingTail
        addSubview(icon)
        addSubview(title)
        icon.setAccessibilityElement(false)
        title.setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func updateText() {
        switch item {
        case .window(let window):
            let isTitleShown = display == .content && !isIconOnly
            title.stringValue = display == .content ? window.title : window.appName
            title.isHidden = isIconOnly
            // The preview panel shows the title, so a tooltip would stack with it.
            let newToolTip = isTitleShown || manager.canPreview ? nil : window.title
            if toolTip != newToolTip { toolTip = newToolTip }
        case .group(_, let windows):
            let label = "\(windows[0].appName) (\(windows.count))"
            title.stringValue = isIconOnly ? String(windows.count) : label
            title.isHidden = false
            let newToolTip = isIconOnly ? label : nil
            if toolTip != newToolTip { toolTip = newToolTip }
        }
    }

    /// The window a preview would show: none on a group, with previews off or without Screen Recording.
    var previewWindow: TrackedWindow? {
        guard manager.canPreview, case .window(let window) = item else { return nil }
        return window
    }

    func showPreview() { manager.preview.show(for: self) }

    private var accessibilityText: String {
        switch item {
        case .window(let window):
            entryAccessibilityLabel(title: window.title, appName: window.appName, isActive: window.isFocused, isMinimized: window.isMinimized)
        case .group(_, let windows):
            groupAccessibilityLabel(appName: windows[0].appName, windowCount: windows.count, isActive: isActive, isMinimized: windows.allSatisfy(\.isMinimized))
        }
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
        title.font = .systemFont(ofSize: 13)
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
        noteFocusRingMaskChanged()
    }

    override func draw(_ dirtyRect: NSRect) {
        // A tile on the focus ring's inset, so entries stand apart from the bar and from each other.
        (isActive ? NSColor.controlAccentColor : NSColor.labelColor.withAlphaComponent(isHovered ? 0.1 : 0.05)).setFill()
        focusRingPath.fill()
        if !isActive {
            // Half a pixel in, so the 1 px hairline lands on whole device pixels.
            let halfPixel = 0.5 / (window?.backingScaleFactor ?? 2)
            let border = NSBezierPath(roundedRect: bounds.insetBy(dx: Self.focusRingInset + halfPixel, dy: Self.focusRingInset + halfPixel), xRadius: 4, yRadius: 4)
            border.lineWidth = 2 * halfPixel
            NSColor.labelColor.withAlphaComponent(0.08).setStroke()
            border.stroke()
        }
        // The system focus ring is accent-derived, so it does not show on the accent fill.
        if isActive && window?.isKeyWindow == true && window?.firstResponder === self {
            NSColor.alternateSelectedControlTextColor.setStroke()
            let outline = focusRingPath
            outline.lineWidth = 2
            outline.stroke()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard isHovered else { return }
        // The grant can have changed since the last snapshot, and the tooltip depends on it.
        updateText()
        showPreview()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        manager.preview.pointerLeft(self)
    }

    override func otherMouseUp(with event: NSEvent) {
        // A group ignores it, so a stray click can't close several windows.
        if event.buttonNumber == 2 && isInside(event), case .window(let window) = item { manager.windowTracker.close(window) }
    }

    // Deferred: a menu's tracking would otherwise hold the accessibility reply until the menu closes.
    override func accessibilityPerformPress() -> Bool {
        Task { @MainActor in performClickAction() }
        return true
    }

    override func performClickAction() {
        manager.preview.dismiss()
        switch item {
        case .window(let window):
            switch clickAction(isActive: window.isFocused, isMinimized: window.isMinimized) {
            case .raise: manager.windowTracker.raise(window)
            case .minimize: manager.windowTracker.minimize(window)
            case .restore: manager.windowTracker.restore(window)
            }
        case .group(_, let windows):
            popUpAbove(windowList(windows))
        }
        (window as? BarPanel)?.endKeyboardMode()
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

    override func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let appName = item.windows[0].appName
        switch item {
        case .window(let window):
            menu.addItem(withTitle: "Close", action: #selector(closeWindows), keyEquivalent: "")
            menu.addItem(withTitle: "Minimize", action: #selector(minimizeWindow), keyEquivalent: "").isEnabled = !window.isMinimized
            let previews = menu.addItem(withTitle: "Show window previews", action: #selector(togglePreviews), keyEquivalent: "")
            previews.state = manager.showsPreviews ? .on : .off
        case .group:
            menu.addItem(withTitle: "Close All Windows", action: #selector(closeWindows), keyEquivalent: "")
        }
        let maybeBar = superview as? BarContentView
        menu.addItem(withTitle: "Move Left", action: #selector(moveEntryLeft), keyEquivalent: "").isEnabled = maybeBar?.canMove(self, by: -1) == true
        menu.addItem(withTitle: "Move Right", action: #selector(moveEntryRight), keyEquivalent: "").isEnabled = maybeBar?.canMove(self, by: 1) == true
        let maybeBundleID = NSRunningApplication(processIdentifier: item.windows[0].pid)?.bundleIdentifier
        if let pinTitle = pinMenuTitle(bundleID: maybeBundleID, pins: manager.pins) {
            menu.addItem(withTitle: pinTitle, action: #selector(togglePin), keyEquivalent: "").representedObject = maybeBundleID
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
        if window.isMinimized { manager.windowTracker.restore(window) } else { manager.windowTracker.raise(window) }
    }

    @objc private func openSettings() { manager.settingsWindow.show() }
    @objc private func togglePreviews() { manager.setShowsPreviews(!manager.showsPreviews) }
    @objc private func closeWindows() { item.windows.forEach(manager.windowTracker.close) }
    @objc private func minimizeWindow() { item.windows.forEach(manager.windowTracker.minimize) }
    @objc private func moveEntryLeft() { (superview as? BarContentView)?.move(self, by: -1) }
    @objc private func moveEntryRight() { (superview as? BarContentView)?.move(self, by: 1) }
    @objc private func togglePin(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        let pins = manager.pins
        manager.setPins(pins.contains(bundleID) ? unpinning(bundleID, in: pins) : pinning(bundleID, in: pins))
    }

    @objc private func quitApp() { NSRunningApplication(processIdentifier: item.windows[0].pid)?.terminate() }
}
