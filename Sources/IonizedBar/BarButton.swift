import AppKit
import Carbon.HIToolbox
import IonizedBarCore

/// A focus stop on the bar: a task entry or an icon button. Holds their hover, focus, keys, menu, and press or drag handling.
class BarButton: NSView {
    private enum Press {
        case none, pressed(at: NSPoint), dragging, abandoned
    }

    static let focusRingInset: CGFloat = 3

    let manager: BarManager
    private(set) var isHovered = false { didSet { needsDisplay = true } }
    private var press = Press.none

    init(manager: BarManager) {
        self.manager = manager
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        focusRingType = .exterior
        // activeAlways: this app is never the active one, and inVisibleRect follows resizes.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var isDraggable: Bool { true }

    /// What a click, Return, Space and VoiceOver's press do.
    func performClickAction() {}

    func contextMenu() -> NSMenu? {
        (superview as? BarContentView)?.barMenu()
    }

    override func mouseEntered(with event: NSEvent) {
        guard manager.preview.dragged == nil else { return }
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) { isHovered = false }

    // Keeps the subviews out of event dispatch: a control-click on a title opens no menu otherwise.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        press = !isDraggable || event.modifierFlags.contains(.control) ? .none : .pressed(at: event.locationInWindow)
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let bar = superview as? BarContentView else { return }
        if case .pressed(let start) = press, isPastDragThreshold(from: start, to: event.locationInWindow) {
            press = bar.beginDrag(self, pressedAt: start) ? .dragging : .abandoned
        }
        if case .dragging = press { bar.moveDrag(to: event.locationInWindow) }
    }

    override func mouseUp(with event: NSEvent) {
        defer { press = .none }
        switch press {
        case .dragging, .abandoned:
            (superview as? BarContentView)?.endDrag()
            // Waits for the drop, like a click: the panel ordering out mid-press could cut the drag short.
            (window as? BarPanel)?.endKeyboardMode()
        case .none, .pressed:
            // A control-click opens the menu: its mouse-up is not a click.
            if isInside(event) && !event.modifierFlags.contains(.control) { performClickAction() }
        }
    }

    /// The drag ended without a drop, so what's left of the press is neither a move nor a click.
    func abandonDrag() { press = .abandoned }

    func isInside(_ event: NSEvent) -> Bool {
        bounds.contains(convert(event.locationInWindow, from: nil))
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        manager.preview.dismiss()
        return contextMenu()
    }

    override var acceptsFirstResponder: Bool { true }

    // Follows acceptsFirstResponder by default, which would make every click take key from the frontmost app.
    override var needsPanelToBecomeKey: Bool { false }

    // Inset: buttons fill the bar, so a ring around the bounds would be clipped by the panel's edges.
    var focusRingPath: NSBezierPath {
        NSBezierPath(roundedRect: bounds.insetBy(dx: Self.focusRingInset, dy: Self.focusRingInset), xRadius: 4, yRadius: 4)
    }

    /// A 1 px outline of `rect`, half a pixel in so it lands on whole device pixels.
    func strokeHairline(around rect: NSRect, color: NSColor = .labelColor.withAlphaComponent(0.08)) {
        let halfPixel = 0.5 / (window?.backingScaleFactor ?? 2)
        let border = NSBezierPath(roundedRect: rect.insetBy(dx: halfPixel, dy: halfPixel), xRadius: 4, yRadius: 4)
        border.lineWidth = 2 * halfPixel
        color.setStroke()
        border.stroke()
    }

    override func drawFocusRingMask() { focusRingPath.fill() }

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
        case kVK_Return, kVK_Space: performClickAction()
        case kVK_F10 where event.modifierFlags.contains(.shift): showContextMenu()
        default: super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        performClickAction()
        return true
    }

    // Deferred: a menu's tracking would otherwise hold the accessibility reply until the menu closes.
    override func accessibilityPerformShowMenu() -> Bool {
        Task { @MainActor in showContextMenu() }
        return true
    }

    private func showContextMenu() {
        manager.preview.dismiss()
        if let menu = contextMenu() { popUpAbove(menu) }
    }

    func popUpAbove(_ menu: NSMenu) {
        // popUp places the menu's top-left at this point, so this puts the whole menu above the button.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + menu.size.height), in: self)
    }
}
