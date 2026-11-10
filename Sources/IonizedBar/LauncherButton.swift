import AppKit
import IonizedBarCore

final class LauncherButton: BarIconButton {
    init(manager: BarManager) {
        let image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: nil)
        super.init(image: image, label: "Open application launcher", manager: manager)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        icon.symbolConfiguration = .init(pointSize: 16 * bounds.height / BarHeight.small.points, weight: .regular)
    }

    override var isDraggable: Bool { false }

    override func open() { manager.launcher.toggle(above: self, pins: manager.pins) }
}
