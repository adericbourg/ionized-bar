import AppKit

final class LauncherButton: BarIconButton {
    init(actions: EntryActions) {
        let image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .regular))
        super.init(image: image, label: "Open application launcher", actions: actions)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func open() { actions.openLauncher(self) }
}
