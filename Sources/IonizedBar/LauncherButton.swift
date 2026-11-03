import AppKit

final class LauncherButton: BarIconButton {
    init(manager: BarManager) {
        let image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .regular))
        super.init(image: image, label: "Open application launcher", manager: manager)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isDraggable: Bool { false }

    override func open() { manager.launcher.toggle(above: self, pins: manager.pins) }
}
