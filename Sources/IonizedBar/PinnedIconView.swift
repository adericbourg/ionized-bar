import AppKit
import IonizedBarCore

/// An app kept on the bar while closed. Takes no window action: a click opens the app, which decides whether to show a window.
final class PinnedIconView: BarIconButton {
    private static let iconSize: CGFloat = 28

    let bundleID: String

    init(bundleID: String, manager: BarManager) {
        self.bundleID = bundleID
        let maybeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let maybeImage = maybeURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
        maybeImage?.size = NSSize(width: Self.iconSize, height: Self.iconSize)
        let name = maybeURL.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID
        super.init(image: maybeImage, label: name, manager: manager)
        setAccessibilityLabel("\(name), pinned")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func open() { manager.openPinnedApp(bundleID) }

    override func contextMenu() -> NSMenu? {
        guard let menu = super.contextMenu() else { return nil }
        menu.autoenablesItems = false
        let maybeBar = superview as? BarContentView
        menu.addItem(.separator())
        let left = menu.addItem(withTitle: "Move Left", action: #selector(movePinLeft), keyEquivalent: "")
        left.target = self
        left.isEnabled = maybeBar?.canMove(self, by: -1) == true
        let right = menu.addItem(withTitle: "Move Right", action: #selector(movePinRight), keyEquivalent: "")
        right.target = self
        right.isEnabled = maybeBar?.canMove(self, by: 1) == true
        menu.addItem(withTitle: "Unpin", action: #selector(unpin), keyEquivalent: "").target = self
        return menu
    }

    @objc private func unpin() { manager.setPins(unpinning(bundleID, in: manager.pins)) }
    @objc private func movePinLeft() { (superview as? BarContentView)?.move(self, by: -1) }
    @objc private func movePinRight() { (superview as? BarContentView)?.move(self, by: 1) }
}
