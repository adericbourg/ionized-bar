import AppKit
import IonizedBarCore

/// An app kept on the bar while closed. Takes no window action: a click opens the app, which decides whether to show a window.
final class PinnedIconView: BarIconButton {
    let bundleID: String
    private var press = EntryView.Press.none

    init(bundleID: String, actions: EntryActions) {
        self.bundleID = bundleID
        let maybeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let maybeImage = maybeURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
        maybeImage?.size = NSSize(width: EntryView.iconSize, height: EntryView.iconSize)
        let name = maybeURL.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID
        super.init(image: maybeImage, label: name, actions: actions)
        setAccessibilityLabel("\(name), pinned")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func open() { actions.openPinnedApp(bundleID) }

    override func mouseDown(with event: NSEvent) {
        press = event.modifierFlags.contains(.control) ? .none : .pressed(at: event.locationInWindow)
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
            // Waits for the drop, as for an entry: the panel ordering out mid-press could cut the drag short.
            (window as? BarPanel)?.endKeyboardMode()
        case .none, .pressed:
            super.mouseUp(with: event)
        }
    }

    /// The drag ended without a drop, so what's left of the press is neither a move nor a click.
    func abandonDrag() { press = .abandoned }

    override func contextMenu() -> NSMenu? {
        guard let menu = super.contextMenu() else { return nil }
        menu.autoenablesItems = false
        let maybeBar = superview as? BarContentView
        menu.insertItem(.separator(), at: 0)
        menu.insertItem(withTitle: "Unpin", action: #selector(unpin), keyEquivalent: "", at: 0).target = self
        let right = menu.insertItem(withTitle: "Move Right", action: #selector(movePinRight), keyEquivalent: "", at: 0)
        right.target = self
        right.isEnabled = maybeBar?.canMove(self, by: 1) == true
        let left = menu.insertItem(withTitle: "Move Left", action: #selector(movePinLeft), keyEquivalent: "", at: 0)
        left.target = self
        left.isEnabled = maybeBar?.canMove(self, by: -1) == true
        return menu
    }

    @objc private func unpin() { actions.setPins(unpinning(bundleID, in: actions.pins())) }
    @objc private func movePinLeft() { (superview as? BarContentView)?.move(self, by: -1) }
    @objc private func movePinRight() { (superview as? BarContentView)?.move(self, by: 1) }
}
