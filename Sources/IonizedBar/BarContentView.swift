import AppKit
import Carbon.HIToolbox
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
    private var pins: [String] = []
    private var pinnedIcons: [PinnedIconView] = []

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

    func update(with windows: [TrackedWindow], settings: Settings, pins: [String]) {
        self.windows = windows
        self.settings = settings
        self.pins = pins
        rebuild()
    }

    // Grouping depends on the width, and the first snapshot can arrive before the first layout.
    override func setFrameSize(_ newSize: NSSize) {
        let isWidthChanged = newSize.width != frame.width
        super.setFrameSize(newSize)
        if isWidthChanged { rebuild() }
    }

    // Read by both the grouping decision and the layout, so that they can't disagree.
    private var slot: (x: CGFloat, width: CGFloat) {
        taskSlot(barWidth: bounds.width, pinnedWidth: CGFloat(pinnedIcons.count) * pinnedIconWidth)
    }

    private func rebuild() {
        let maybeFocused = window?.firstResponder as? NSView
        let focusedIndex = focusStops.firstIndex { $0 === maybeFocused }
        let previousIcons = pinnedIcons
        pinnedIcons = pins.map { bundleID in previousIcons.first { $0.bundleID == bundleID } ?? addPinnedIcon(bundleID) }
        for icon in previousIcons where !pinnedIcons.contains(icon) { icon.removeFromSuperview() }
        let items = barItems(
            windows, pid: \.pid, barWidth: slot.width, mode: settings.grouping,
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
            actions.preview.dismiss(for: entry)
            animate({ entry.animator().alphaValue = 0 }) { [weak self] in
                MainActor.assumeIsolated { self?.finishLeaving(entry) }
            }
        }
        if let focusedIndex, !focusStops.contains(where: { $0 === maybeFocused }) {
            window?.makeFirstResponder(focusStops[min(focusedIndex, focusStops.count - 1)])
        }
        needsLayout = true
    }

    // In visual order, without the entries fading out: Tab order and VoiceOver's order.
    private var focusStops: [NSView] { [launcher] + pinnedIcons + ordered }

    var initialFocusStop: NSView { ordered.first(where: \.isActive) ?? focusStops[0] }

    // A stop handles the keys that act on it and leaves these to come up the responder chain.
    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Tab: moveFocus(by: event.modifierFlags.contains(.shift) ? -1 : 1)
        case kVK_LeftArrow: moveFocus(by: -1)
        case kVK_RightArrow: moveFocus(by: 1)
        case kVK_Escape: (window as? BarPanel)?.endKeyboardMode()
        default: super.keyDown(with: event)
        }
    }

    private func moveFocus(by offset: Int) {
        let stops = focusStops
        guard let index = stops.firstIndex(where: { $0 === window?.firstResponder }) else { return }
        window?.makeFirstResponder(stops[(index + offset + stops.count) % stops.count])
    }

    override func accessibilityChildren() -> [Any]? { focusStops }

    private func addPinnedIcon(_ bundleID: String) -> PinnedIconView {
        let icon = PinnedIconView(bundleID: bundleID, actions: actions)
        addSubview(icon)
        return icon
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
        launcher.frame = backingAlignedRect(CGRect(x: 0, y: 0, width: launcherWidth, height: bounds.height), options: .alignAllEdgesNearest)
        for (index, icon) in pinnedIcons.enumerated() {
            icon.frame = backingAlignedRect(CGRect(x: launcherWidth + CGFloat(index) * pinnedIconWidth, y: 0, width: pinnedIconWidth, height: bounds.height), options: .alignAllEdgesNearest)
        }
        let slot = self.slot
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
