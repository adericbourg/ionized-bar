import AppKit
import IonizedBarCore

private enum EntryKey: Hashable {
    case window(AXUIElement)
    case group(pid_t)

    init(_ item: BarItem<TrackedWindow>) {
        switch item {
        case .window(let window): self = .window(window.element)
        case .group(let pid, _): self = .group(pid)
        }
    }
}

final class BarContentView: NSView {
    private let actions: EntryActions
    private var entries: [EntryKey: EntryView] = [:]
    private var ordered: [EntryView] = []
    // Entries fading out; one is revived if its window or group returns before the fade ends.
    private var leaving: [EntryKey: EntryView] = [:]
    private var windows: [TrackedWindow] = []
    private var settings = Settings.load()

    private static let duration: TimeInterval = 0.12
    private static let iconOnlyWidth: CGFloat = 48
    private static let groupWhenFullBelow: CGFloat = 120
    private var isMotionReduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    init(actions: EntryActions) {
        self.actions = actions
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func animate(_ changes: () -> Void, completion: (@Sendable () -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = isMotionReduced ? 0 : Self.duration
            changes()
        }, completionHandler: completion)
    }

    func update(with windows: [TrackedWindow], settings: Settings) {
        self.windows = windows
        self.settings = settings
        rebuild()
    }

    // Grouping depends on the width, and the first snapshot can arrive before the first layout.
    override func setFrameSize(_ newSize: NSSize) {
        let isWidthChanged = newSize.width != frame.width
        super.setFrameSize(newSize)
        if isWidthChanged { rebuild() }
    }

    private func rebuild() {
        let items = barItems(
            windows, pid: \.pid, barWidth: bounds.width, mode: settings.grouping,
            minEntryWidth: settings.taskDisplay == .iconOnly ? Self.iconOnlyWidth : Self.groupWhenFullBelow
        )
        var gone = entries
        ordered = items.map { item in
            let key = EntryKey(item)
            let entry = entries[key] ?? revive(key) ?? addEntry(item)
            entries[key] = entry
            gone[key] = nil
            entry.update(with: item, display: settings.taskDisplay)
            return entry
        }
        for (key, entry) in gone {
            entries[key] = nil
            leaving[key] = entry
            animate({ entry.animator().alphaValue = 0 }) { [weak self] in
                MainActor.assumeIsolated { self?.finishLeaving(entry) }
            }
        }
        needsLayout = true
    }

    private func addEntry(_ item: BarItem<TrackedWindow>) -> EntryView {
        let entry = EntryView(item: item, actions: actions)
        entry.alphaValue = 0
        addSubview(entry)
        animate { entry.animator().alphaValue = 1 }
        return entry
    }

    private func finishLeaving(_ entry: EntryView) {
        guard let key = leaving.first(where: { $0.value === entry })?.key else { return }
        entry.removeFromSuperview()
        leaving[key] = nil
    }

    private func revive(_ key: EntryKey) -> EntryView? {
        guard let entry = leaving.removeValue(forKey: key) else { return nil }
        animate { entry.animator().alphaValue = 1 }
        return entry
    }

    override func layout() {
        super.layout()
        let isIconOnlyMode = settings.taskDisplay == .iconOnly
        let layoutWidth = isIconOnlyMode
            ? entryWidth(barWidth: bounds.width, entryCount: ordered.count, maxWidth: Self.iconOnlyWidth)
            : entryWidth(barWidth: bounds.width, entryCount: ordered.count)
        for (index, entry) in ordered.enumerated() {
            entry.isIconOnly = isIconOnlyMode || layoutWidth.isIconOnly
            let target = backingAlignedRect(CGRect(x: CGFloat(index) * layoutWidth.width, y: 0, width: layoutWidth.width, height: bounds.height), options: .alignAllEdgesNearest)
            if entry.frame == .zero {
                entry.frame = target
            } else if entry.frame != target {
                animate { entry.animator().frame = target }
            }
        }
    }

    // Backing alignment changes with the scale.
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }
}
