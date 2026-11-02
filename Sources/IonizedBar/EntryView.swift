import AppKit

final class EntryView: NSView {
    private static let padding: CGFloat = 8
    private static let iconSize: CGFloat = 16

    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private var isActive = false { didSet { needsDisplay = true } }
    private var isHovered = false { didSet { needsDisplay = true } }
    var isIconOnly = false {
        didSet {
            guard isIconOnly != oldValue else { return }
            title.isHidden = isIconOnly
            toolTip = isIconOnly ? title.stringValue : nil
            needsLayout = true
        }
    }

    init(pid: pid_t) {
        super.init(frame: .zero)
        icon.image = NSRunningApplication(processIdentifier: pid)?.icon
        title.lineBreakMode = .byTruncatingTail
        addSubview(icon)
        addSubview(title)
        // activeAlways: this app is never the active one, and inVisibleRect follows resizes.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(with window: TrackedWindow) {
        isActive = window.isFocused
        icon.alphaValue = window.isMinimized ? 0.5 : 1
        title.stringValue = window.title
        if isIconOnly { toolTip = window.title }
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
}
