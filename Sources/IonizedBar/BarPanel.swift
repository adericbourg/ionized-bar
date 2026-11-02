import AppKit

final class BarPanel: NSPanel {
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
        contentView = BarBackground()
    }
}

private final class BarBackground: NSVisualEffectView {
    private let hairline = HairlineView()

    init() {
        super.init(frame: .zero)
        blendingMode = .behindWindow
        state = .active
        material = .hudWindow
        addSubview(hairline)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let thickness = 1 / (window?.backingScaleFactor ?? 1)
        hairline.frame = CGRect(x: 0, y: bounds.height - thickness, width: bounds.width, height: thickness)
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
