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
    private let launcher: LauncherButton
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
        launcher = LauncherButton(actions: actions)
        super.init(frame: .zero)
        addSubview(launcher)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Taskbar")
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
            windows, pid: \.pid, barWidth: taskSlot(barWidth: bounds.width).width, mode: settings.grouping,
            minEntryWidth: settings.taskDisplay == .iconOnly ? Self.iconOnlyWidth : Self.groupWhenFullBelow
        )
        let maybeFocused = window?.firstResponder as? EntryView
        let focusedIndex = ordered.firstIndex { $0 === maybeFocused }
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
            actions.preview.dismiss(for: entry)
            animate({ entry.animator().alphaValue = 0 }) { [weak self] in
                MainActor.assumeIsolated { self?.finishLeaving(entry) }
            }
        }
        if let maybeFocused, let focusedIndex, !ordered.contains(maybeFocused) {
            if ordered.isEmpty {
                (window as? BarPanel)?.endKeyboardMode()
            } else {
                window?.makeFirstResponder(ordered[min(focusedIndex, ordered.count - 1)])
            }
        }
        needsLayout = true
    }

    var initialFocusEntry: EntryView? { ordered.first(where: \.isActive) ?? ordered.first }

    func moveFocus(from entry: EntryView, by offset: Int) {
        guard let index = ordered.firstIndex(of: entry) else { return }
        window?.makeFirstResponder(ordered[(index + offset + ordered.count) % ordered.count])
    }

    // In visual order, without the entries fading out.
    override func accessibilityChildren() -> [Any]? { [launcher] + ordered }

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
        launcher.frame = backingAlignedRect(CGRect(x: 0, y: 0, width: launcherWidth, height: bounds.height), options: .alignAllEdgesNearest)
        let slot = taskSlot(barWidth: bounds.width)
        let isIconOnlyMode = settings.taskDisplay == .iconOnly
        let layoutWidth = isIconOnlyMode
            ? entryWidth(barWidth: slot.width, entryCount: ordered.count, maxWidth: Self.iconOnlyWidth)
            : entryWidth(barWidth: slot.width, entryCount: ordered.count)
        for (index, entry) in ordered.enumerated() {
            entry.isIconOnly = isIconOnlyMode || layoutWidth.isIconOnly
            let target = backingAlignedRect(CGRect(x: slot.x + CGFloat(index) * layoutWidth.width, y: 0, width: layoutWidth.width, height: bounds.height), options: .alignAllEdgesNearest)
            if entry.frame == .zero {
                entry.frame = target
            } else if entry.frame != target {
                actions.preview.dismiss(for: entry)
                animate { entry.animator().frame = target }
            }
        }
    }

    // Keeps settings reachable with no windows open.
    override func menu(for event: NSEvent) -> NSMenu? { barMenu() }

    func barMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit IonizedBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "").target = NSApp
        return menu
    }

    @objc private func openSettings() { actions.openSettings() }

    // Backing alignment changes with the scale.
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }
}
