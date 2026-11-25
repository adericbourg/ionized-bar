import AppKit
import IonizedBarCore

/// One plugged-in device: a click lists its volumes and what can be done with each.
final class DevicesButton: BarIconButton {
    private(set) var device: Device

    init(device: Device, manager: BarManager) {
        self.device = device
        super.init(image: NSImage(systemSymbolName: "externaldrive", accessibilityDescription: nil), label: deviceLabel(device), manager: manager)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(with newDevice: Device) {
        device = newDevice
        toolTip = deviceLabel(device)
        setAccessibilityLabel(deviceLabel(device))
    }

    override func layout() {
        super.layout()
        icon.symbolConfiguration = .init(pointSize: 16 * bounds.height / BarHeight.small.points, weight: .regular)
    }

    override var isDraggable: Bool { false }

    override func open() {
        let menu = NSMenu()
        menu.addItem(.sectionHeader(title: device.name))
        for volume in device.volumes {
            menu.addItem(disabledItem(volume.name, indentation: 0))
            guard let url = volume.maybeMountURL else {
                menu.addItem(item("Mount", #selector(mount), volume.bsdName))
                continue
            }
            if let capacity = Self.capacity(of: url) { menu.addItem(disabledItem(capacity, indentation: 1)) }
            menu.addItem(item("Open in Finder", #selector(openInFinder), url))
            menu.addItem(item("Eject", #selector(eject), volume.bsdName))
        }
        if device.volumes.count > 1 {
            menu.addItem(.separator())
            menu.addItem(withTitle: "Eject All", action: #selector(ejectAll), keyEquivalent: "").target = self
        }
        popUpAbove(menu)
    }

    /// "12.3 GB free of 64 GB", read when the menu opens.
    private static func capacity(of url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey, .volumeTotalCapacityKey]),
              let free = values.volumeAvailableCapacityForImportantUsage ?? values.volumeAvailableCapacity.map(Int64.init),
              let total = values.volumeTotalCapacity
        else { return nil }
        return "\(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))"
    }

    private func disabledItem(_ title: String, indentation: Int) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.indentationLevel = indentation
        return item
    }

    private func item(_ title: String, _ action: Selector, _ representedObject: Any) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = representedObject
        item.indentationLevel = 1
        return item
    }

    @objc private func openInFinder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func mount(_ sender: NSMenuItem) {
        guard let volume = device.volumes.first(where: { $0.bsdName == sender.representedObject as? String }) else { return }
        manager.deviceMonitor.mount(volume)
    }

    @objc private func eject(_ sender: NSMenuItem) {
        guard let volume = device.volumes.first(where: { $0.bsdName == sender.representedObject as? String }) else { return }
        manager.deviceMonitor.eject(volume, of: device)
    }

    @objc private func ejectAll() { manager.deviceMonitor.ejectAll(device) }
}
