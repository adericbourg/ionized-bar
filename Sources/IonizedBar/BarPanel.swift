import AppKit

/// Goes under a panel's content: the frosted material alone turns mid-grey over a light backdrop, even with a dark appearance.
@MainActor
func makeDarkTint(cornerRadius: CGFloat = 0) -> NSView {
    let tint = NSView()
    tint.wantsLayer = true
    tint.layer?.backgroundColor = NSColor(white: 0.11, alpha: 0.8).cgColor
    tint.layer?.cornerRadius = cornerRadius
    tint.autoresizingMask = [.width, .height]
    return tint
}

final class BarPanel: NSPanel {
    private let content: BarContentView
    private let preview: PreviewController

    init(frame: CGRect, actions: EntryActions) {
        content = BarContentView(actions: actions)
        preview = actions.preview
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        // Without fullScreenNone, canJoinAllSpaces also puts the panel on fullscreen Spaces, above the fullscreen window.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .darkAqua)
        let surface = BarSurface(content: content)
        let frosted = NSVisualEffectView()
        frosted.blendingMode = .behindWindow
        frosted.state = .active
        frosted.material = .hudWindow
        let tint = makeDarkTint()
        tint.frame = frosted.bounds
        frosted.addSubview(tint)
        surface.frame = frosted.bounds
        surface.autoresizingMask = [.width, .height]
        frosted.addSubview(surface)
        contentView = frosted
    }

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if content.isDragging {
            // Another left press: the drag's mouse-up never came, for instance taken by a system gesture.
            if event.type == .leftMouseDown { content.cancelDrag() }
            // Keyboard mode's keys, a menu or a middle click would act on what the drag is moving.
            if [.keyDown, .rightMouseDown, .otherMouseUp].contains(event.type) { return }
        }
        super.sendEvent(event)
    }

    func update(with windows: [TrackedWindow], settings: Settings, pins: [String]) {
        content.update(with: windows, settings: settings, pins: pins)
    }

    // Losing key does not resign first responder, so the focus outline would stay drawn.
    override func resignKey() {
        super.resignKey()
        makeFirstResponder(nil)
        preview.dismiss()
    }

    // Key only: clicking an entry also makes it first responder, on a panel that isn't key.
    // Here rather than in EntryView: a clicked entry stays first responder, so ⌃⌥B wouldn't call its becomeFirstResponder.
    @discardableResult
    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        let isMade = super.makeFirstResponder(responder)
        if isKeyWindow {
            if let entry = responder as? EntryView { entry.showPreview() } else { preview.dismiss() }
        }
        return isMade
    }

    // A clicked entry stays first responder on the non-key panel, so makeFirstResponder is a no-op
    // and nothing redraws the focus outline.
    override func becomeKey() {
        super.becomeKey()
        (firstResponder as? NSView)?.needsDisplay = true
    }

    func beginKeyboardMode() {
        // False on a fullscreen Space, where the bar is not shown.
        guard isOnActiveSpace else { return }
        makeKey()
        makeFirstResponder(content.initialFocusStop)
    }

    func endKeyboardMode() {
        guard isKeyWindow else { return }
        // resignKey() alone does not hand key back to the frontmost app.
        orderOut(nil)
        orderFrontRegardless()
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
