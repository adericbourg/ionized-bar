import AppKit
import IonizedBarCore

/// An app kept on the bar while closed. Takes no window action: a click opens the app, which decides whether to show a window.
final class PinnedIconView: BarIconButton {
    let bundleID: String

    init(bundleID: String, actions: EntryActions) {
        self.bundleID = bundleID
        let maybeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let maybeImage = maybeURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
        maybeImage?.size = NSSize(width: EntryView.iconSize, height: EntryView.iconSize)
        super.init(image: maybeImage, label: maybeURL?.deletingPathExtension().lastPathComponent ?? bundleID, actions: actions)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func open() { actions.openPinnedApp(bundleID) }

    override func contextMenu() -> NSMenu? {
        guard let menu = super.contextMenu() else { return nil }
        menu.insertItem(.separator(), at: 0)
        menu.insertItem(withTitle: "Unpin", action: #selector(unpin), keyEquivalent: "", at: 0).target = self
        return menu
    }

    @objc private func unpin() { actions.setPins(unpinning(bundleID, in: actions.pins())) }
}
