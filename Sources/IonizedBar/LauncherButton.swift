import AppKit

/// Not an `EntryView`: it stands for no window, so it has no preview, no window action and makes no AX call.
final class LauncherButton: NSView {
    private static let label = "Open application launcher"

    private let actions: EntryActions
    private var isHovered = false { didSet { needsDisplay = true } }

    init(actions: EntryActions) {
        self.actions = actions
        super.init(frame: .zero)
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .regular))
        icon.contentTintColor = .labelColor
        icon.autoresizingMask = [.width, .height]
        icon.setAccessibilityElement(false)
        addSubview(icon)
        toolTip = Self.label
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(Self.label)
        // activeAlways: this app is never the active one, and inVisibleRect follows resizes.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard isHovered else { return }
        NSColor.labelColor.withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }

    override func mouseExited(with event: NSEvent) { isHovered = false }

    // Keeps the icon out of event dispatch, as in EntryView.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseUp(with event: NSEvent) {
        // A control-click opens the menu: its mouse-up is not a click.
        if bounds.contains(convert(event.locationInWindow, from: nil)) && !event.modifierFlags.contains(.control) { open() }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        actions.preview.dismiss()
        return (superview as? BarContentView)?.barMenu()
    }

    override func accessibilityPerformPress() -> Bool {
        open()
        return true
    }

    // Deferred: a menu's tracking would otherwise hold the accessibility reply until the menu closes.
    override func accessibilityPerformShowMenu() -> Bool {
        Task { @MainActor in
            guard let menu = (superview as? BarContentView)?.barMenu() else { return }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + menu.size.height), in: self)
        }
        return true
    }

    private func open() {
        actions.preview.dismiss()
        (window as? BarPanel)?.endKeyboardMode()
        actions.openLauncher(self)
    }
}
