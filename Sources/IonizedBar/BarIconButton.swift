import AppKit

/// A fixed-width icon button on the bar. Not an `EntryView`: it stands for no window, so it has no preview, no window action and makes no AX call.
class BarIconButton: BarButton {
    init(image: NSImage?, label: String, manager: BarManager) {
        super.init(manager: manager)
        let icon = NSImageView()
        icon.image = image
        icon.contentTintColor = .labelColor
        icon.autoresizingMask = [.width, .height]
        icon.setAccessibilityElement(false)
        addSubview(icon)
        toolTip = label
        setAccessibilityLabel(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func open() {}

    override func draw(_ dirtyRect: NSRect) {
        guard isHovered else { return }
        NSColor.labelColor.withAlphaComponent(0.1).setFill()
        // Same height as a task tile, kept square.
        let side = bounds.height - 2 * Self.focusRingInset
        let tile = NSRect(x: (bounds.width - side) / 2, y: Self.focusRingInset, width: side, height: side)
        NSBezierPath(roundedRect: tile, xRadius: 4, yRadius: 4).fill()
        strokeHairline(around: tile)
    }

    override func performClickAction() {
        manager.preview.dismiss()
        (window as? BarPanel)?.endKeyboardMode()
        open()
    }
}
