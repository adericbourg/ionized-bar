import AppKit
import Carbon.HIToolbox

/// A fixed-width icon button on the bar. Not an `EntryView`: it stands for no window, so it has no preview, no window action and makes no AX call.
class BarIconButton: NSView {
    let actions: EntryActions
    private var isHovered = false { didSet { needsDisplay = true } }

    init(image: NSImage?, label: String, actions: EntryActions) {
        self.actions = actions
        super.init(frame: .zero)
        let icon = NSImageView()
        icon.image = image
        icon.contentTintColor = .labelColor
        icon.autoresizingMask = [.width, .height]
        icon.setAccessibilityElement(false)
        addSubview(icon)
        toolTip = label
        focusRingType = .exterior
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(label)
        // activeAlways: this app is never the active one, and inVisibleRect follows resizes.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// What a click, Return, Space and VoiceOver's press do.
    func open() {}

    func contextMenu() -> NSMenu? {
        (superview as? BarContentView)?.barMenu()
    }

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
        if bounds.contains(convert(event.locationInWindow, from: nil)) && !event.modifierFlags.contains(.control) { press() }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        actions.preview.dismiss()
        return contextMenu()
    }

    override var acceptsFirstResponder: Bool { true }

    // Follows acceptsFirstResponder by default, which would make every click take key from the frontmost app.
    override var needsPanelToBecomeKey: Bool { false }

    // Inset, as in EntryView: the button fills the bar's height.
    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds.insetBy(dx: EntryView.focusRingInset, dy: EntryView.focusRingInset), xRadius: 4, yRadius: 4).fill()
    }

    override var focusRingMaskBounds: NSRect { bounds }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Return, kVK_Space: press()
        case kVK_F10 where event.modifierFlags.contains(.shift): showMenu()
        default: super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        press()
        return true
    }

    // Deferred: a menu's tracking would otherwise hold the accessibility reply until the menu closes.
    override func accessibilityPerformShowMenu() -> Bool {
        Task { @MainActor in showMenu() }
        return true
    }

    private func showMenu() {
        actions.preview.dismiss()
        guard let menu = contextMenu() else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + menu.size.height), in: self)
    }

    private func press() {
        actions.preview.dismiss()
        (window as? BarPanel)?.endKeyboardMode()
        open()
    }
}
