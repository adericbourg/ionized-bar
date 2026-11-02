import AppKit
import IonizedBarCore

struct EntryActions {
    let raise: (TrackedWindow) -> Void
    let minimize: (TrackedWindow) -> Void
    let restore: (TrackedWindow) -> Void
    let close: (TrackedWindow) -> Void
}

final class EntryView: NSView {
    private static let padding: CGFloat = 8
    private static let iconSize: CGFloat = 16

    private let actions: EntryActions
    private var tracked: TrackedWindow
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

    init(window: TrackedWindow, actions: EntryActions) {
        tracked = window
        self.actions = actions
        super.init(frame: .zero)
        icon.image = NSRunningApplication(processIdentifier: window.pid)?.icon
        title.lineBreakMode = .byTruncatingTail
        addSubview(icon)
        addSubview(title)
        // activeAlways: this app is never the active one, and inVisibleRect follows resizes.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func updateText() {
        let isTitleShown = display == .content && !isIconOnly
        title.stringValue = display == .content ? tracked.title : tracked.appName
        title.isHidden = isIconOnly
        toolTip = isTitleShown ? nil : tracked.title
    }

    func update(with window: TrackedWindow, display: TaskDisplay) {
        tracked = window
        self.display = display
        updateText()
        isActive = window.isFocused
        icon.alphaValue = window.isMinimized ? 0.5 : 1
        let font = NSFont.systemFont(ofSize: 13)
        title.font = window.isMinimized ? NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) : font
        title.textColor = window.isFocused ? .alternateSelectedControlTextColor : window.isMinimized ? .secondaryLabelColor : .labelColor
    }

    override func layout() {
        super.layout()
        // Rounded: an integer point is on a device pixel at every scale, so the icon and text stay sharp.
        let iconX = isIconOnly ? ((bounds.width - Self.iconSize) / 2).rounded() : Self.padding
        icon.frame = CGRect(x: iconX, y: ((bounds.height - Self.iconSize) / 2).rounded(), width: Self.iconSize, height: Self.iconSize)
        let titleX = icon.frame.maxX + Self.padding
        let titleHeight = title.intrinsicContentSize.height
        title.frame = CGRect(x: titleX, y: ((bounds.height - titleHeight) / 2).rounded(), width: max(0, bounds.width - titleX - Self.padding), height: titleHeight)
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
        if event.buttonNumber == 2 && isInside(event) { actions.close(tracked) }
    }

    override func menu(for event: NSEvent) -> NSMenu? { contextMenu() }

    private func isInside(_ event: NSEvent) -> Bool {
        bounds.contains(convert(event.locationInWindow, from: nil))
    }

    func performClickAction() {
        switch clickAction(isActive: tracked.isFocused, isMinimized: tracked.isMinimized) {
        case .raise: actions.raise(tracked)
        case .minimize: actions.minimize(tracked)
        case .restore: actions.restore(tracked)
        }
    }

    func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(withTitle: "Close", action: #selector(closeWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Minimize", action: #selector(minimizeWindow), keyEquivalent: "").isEnabled = !tracked.isMinimized
        menu.addItem(withTitle: "Quit \(tracked.appName)", action: #selector(quitApp), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func closeWindow() { actions.close(tracked) }
    @objc private func minimizeWindow() { actions.minimize(tracked) }
    @objc private func quitApp() { NSRunningApplication(processIdentifier: tracked.pid)?.terminate() }
}
