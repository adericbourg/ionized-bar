import AppKit

/// A square of the pager: a click switches to its desktop.
final class DesktopButton: BarButton {
    private static let inset: CGFloat = 1.5

    let desktop: Int
    var isCurrent = false {
        didSet {
            guard isCurrent != oldValue else { return }
            needsDisplay = true
            setAccessibilityLabel(label)
        }
    }
    private let number = NSTextField(labelWithString: "")

    init(desktop: Int, manager: BarManager) {
        self.desktop = desktop
        super.init(manager: manager)
        number.stringValue = String(desktop)
        number.alignment = .center
        number.textColor = .labelColor
        number.setAccessibilityElement(false)
        addSubview(number)
        setAccessibilityLabel(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private var label: String { isCurrent ? "Desktop \(desktop), current" : "Desktop \(desktop)" }

    override var isDraggable: Bool { false }

    override func performClickAction() {
        manager.preview.dismiss()
        (window as? BarPanel)?.endKeyboardMode()
        manager.desktops.switchTo(desktop)
    }

    // The squares are small: the bar buttons' inset would leave little of them.
    override var focusRingPath: NSBezierPath {
        NSBezierPath(roundedRect: bounds.insetBy(dx: Self.inset, dy: Self.inset), xRadius: 3, yRadius: 3)
    }

    override func layout() {
        super.layout()
        number.font = .monospacedDigitSystemFont(ofSize: min(13, max(9, (bounds.height * 0.55).rounded())), weight: .regular)
        let height = number.intrinsicContentSize.height
        number.frame = CGRect(x: 0, y: ((bounds.height - height) / 2).rounded(), width: bounds.width, height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        // As a task entry: the accent tint and outline mark the current one.
        (isCurrent ? NSColor.controlAccentColor.withAlphaComponent(0.3) : NSColor.labelColor.withAlphaComponent(isHovered ? 0.1 : 0.05)).setFill()
        focusRingPath.fill()
        let tile = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        if isCurrent {
            strokeHairline(around: tile, color: .controlAccentColor)
        } else {
            strokeHairline(around: tile)
        }
    }
}
