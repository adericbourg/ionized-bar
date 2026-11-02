import AppKit

final class BarPanel: NSPanel {
    private let content = BarContentView()

    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        let surface = BarSurface(content: content)
        // ponytail: temporary switch to compare materials by eye; delete it and the losing branch once the user picks.
        if ProcessInfo.processInfo.environment["IONIZED_BAR_MATERIAL"] == "liquid" {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 0
            glass.contentView = surface
            contentView = glass
        } else {
            let frosted = NSVisualEffectView()
            frosted.blendingMode = .behindWindow
            frosted.state = .active
            frosted.material = .hudWindow
            surface.frame = frosted.bounds
            surface.autoresizingMask = [.width, .height]
            frosted.addSubview(surface)
            contentView = frosted
        }
    }

    func update(with windows: [TrackedWindow]) {
        content.update(with: windows)
    }
}

private final class BarSurface: NSView {
    private let content: NSView
    private let hairline = HairlineView()

    init(content: NSView) {
        self.content = content
        super.init(frame: .zero)
        addSubview(content)
        addSubview(hairline)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let thickness = 1 / (window?.backingScaleFactor ?? 1)
        hairline.frame = CGRect(x: 0, y: bounds.height - thickness, width: bounds.width, height: thickness)
        content.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - thickness)
    }

    // One device pixel changes with the backing scale (e.g. moving between displays).
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }
}

/// Redrawn on appearance changes, so the separator color follows light/dark.
private final class HairlineView: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.separatorColor.cgColor
    }
}
