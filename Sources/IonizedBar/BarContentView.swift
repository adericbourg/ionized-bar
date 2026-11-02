import AppKit
import IonizedBarCore

final class BarContentView: NSView {
    private var entries: [AXUIElement: EntryView] = [:]
    private var ordered: [EntryView] = []

    func update(with windows: [TrackedWindow]) {
        var gone = entries
        ordered = windows.map { window in
            let entry = entries[window.element] ?? addEntry(pid: window.pid)
            entries[window.element] = entry
            gone[window.element] = nil
            entry.update(with: window)
            return entry
        }
        for (element, entry) in gone {
            entry.removeFromSuperview()
            entries[element] = nil
        }
        needsLayout = true
    }

    private func addEntry(pid: pid_t) -> EntryView {
        let entry = EntryView(pid: pid)
        addSubview(entry)
        return entry
    }

    override func layout() {
        super.layout()
        let width = entryWidth(barWidth: bounds.width, entryCount: ordered.count).width
        for (index, entry) in ordered.enumerated() {
            entry.frame = backingAlignedRect(CGRect(x: CGFloat(index) * width, y: 0, width: width, height: bounds.height), options: .alignAllEdgesNearest)
        }
    }

    // Backing alignment changes with the scale.
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }
}
