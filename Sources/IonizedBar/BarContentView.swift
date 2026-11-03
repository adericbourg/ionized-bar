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
    private struct Drag {
        let button: BarButton
        let grabOffset: CGFloat
        var pointerX: CGFloat
        var to: Int
    }

    private let manager: BarManager
    private let launcher: LauncherButton
    private var entries: [EntryKey: EntryView] = [:]
    private var ordered: [EntryView] = []
    // What `ordered` shows, for `moveEntry`.
    private var items: [BarItem<TrackedWindow>] = []
    private var maybeDrag: Drag?
    // Entries fading out; one is revived if its window or group returns before the fade ends.
    private var leaving: [EntryKey: EntryView] = [:]
    private var windows: [TrackedWindow] = []
    private var settings = Settings.load()
    private var pins: [String] = []
    private var pinnedIcons: [PinnedIconView] = []
    // Fading out; one is revived if its pin returns before the fade ends.
    private var leavingIcons: [PinnedIconView] = []

    private static let duration: TimeInterval = 0.12
    private static let iconOnlyWidth: CGFloat = 48
    private static let groupWhenFullBelow: CGFloat = 120
    private var isMotionReduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    init(manager: BarManager) {
        self.manager = manager
        launcher = LauncherButton(manager: manager)
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
        pinnedIcons = pins.map { bundleID in previousIcons.first { $0.bundleID == bundleID } ?? reviveIcon(bundleID) ?? addPinnedIcon(bundleID) }
        for icon in previousIcons where !pinnedIcons.contains(icon) {
            leavingIcons.append(icon)
            animate({ icon.animator().alphaValue = 0 }) { [weak self] in
                MainActor.assumeIsolated { self?.finishLeaving(icon) }
            }
        }
        items = barItems(
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
            manager.preview.dismiss(for: entry)
            animate({ entry.animator().alphaValue = 0 }) { [weak self] in
                MainActor.assumeIsolated { self?.finishLeaving(entry) }
            }
        }
        if let maybeDrag, !focusStops.contains(maybeDrag.button) { cancelDrag() }
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
        let icon = PinnedIconView(bundleID: bundleID, manager: manager)
        icon.alphaValue = 0
        addSubview(icon)
        animate { icon.animator().alphaValue = 1 }
        return icon
    }

    private func finishLeaving(_ icon: PinnedIconView) {
        guard let index = leavingIcons.firstIndex(of: icon) else { return }
        icon.removeFromSuperview()
        leavingIcons.remove(at: index)
    }

    private func reviveIcon(_ bundleID: String) -> PinnedIconView? {
        guard let index = leavingIcons.firstIndex(where: { $0.bundleID == bundleID }) else { return nil }
        let icon = leavingIcons.remove(at: index)
        animate { icon.animator().alphaValue = 1 }
        return icon
    }

    private func addEntry(_ item: BarItem<TrackedWindow>) -> EntryView {
        let entry = EntryView(item: item, manager: manager)
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

    var isDragging: Bool { maybeDrag != nil }

    private func row(of button: BarButton) -> [BarButton] {
        button is PinnedIconView ? pinnedIcons : ordered
    }

    /// False for a button fading out. Asked again when the menu item fires, as the bar can have changed since the menu opened.
    func canMove(_ button: BarButton, by offset: Int) -> Bool {
        let row = row(of: button)
        guard let index = row.firstIndex(of: button) else { return false }
        return row.indices.contains(index + offset)
    }

    /// One slot, through the same move as a drop there.
    func move(_ button: BarButton, by offset: Int) {
        guard canMove(button, by: offset), let from = row(of: button).firstIndex(of: button) else { return }
        reorder(button, from: from, to: from + offset)
    }

    private func reorder(_ button: BarButton, from: Int, to: Int) {
        if button is PinnedIconView {
            // Among the pins this bar shows: the others keep their place.
            manager.setPins(movingPin(in: manager.pins, shown: pins, from: from, to: to))
        } else {
            manager.moveEntry(items, from: from, to: to)
        }
    }

    /// False for a button already fading out.
    func beginDrag(_ button: BarButton, pressedAt start: NSPoint) -> Bool {
        guard let from = row(of: button).firstIndex(of: button) else { return false }
        let pressX = convert(start, from: nil).x
        maybeDrag = Drag(button: button, grabOffset: pressX - button.frame.minX, pointerX: pressX, to: from)
        manager.preview.dragged = button
        needsLayout = true
        return true
    }

    func moveDrag(to location: NSPoint) {
        guard var drag = maybeDrag else { return }
        drag.pointerX = convert(location, from: nil).x
        maybeDrag = drag
        // Only the dragged frame on each event: a layout per event would restart the others' slides.
        placeDragged(drag)
        if dragPlace(drag).to != drag.to { needsLayout = true }
    }

    func endDrag() {
        guard let drag = maybeDrag else { return }
        let place = dragPlace(drag)
        finishDrag()
        guard place.to != place.from else { return }
        reorder(drag.button, from: place.from, to: place.to)
    }

    func cancelDrag() {
        maybeDrag?.button.abandonDrag()
        finishDrag()
    }

    private func finishDrag() {
        maybeDrag = nil
        manager.preview.dragged = nil
        needsLayout = true
    }

    // What the dragged view moves along: pins stay between the launcher and the tasks, tasks stay after the pins.
    private func dragRow(_ drag: Drag) -> (views: [BarButton], slotX: CGFloat, width: CGFloat) {
        drag.button is PinnedIconView ? (pinnedIcons, launcherWidth, pinnedIconWidth) : (ordered, slot.x, layoutWidth.width)
    }

    private func dragPlace(_ drag: Drag) -> (x: CGFloat, from: Int, to: Int) {
        let row = dragRow(drag)
        let from = row.views.firstIndex(of: drag.button) ?? 0
        let x = draggedEntryX(pointerX: drag.pointerX, grabOffset: drag.grabOffset, slotX: row.slotX, entryWidth: row.width, entryCount: row.views.count)
        return (x, from, dragTargetIndex(entryX: x, from: from, slotX: row.slotX, entryWidth: row.width, entryCount: row.views.count))
    }

    private func placeDragged(_ drag: Drag) {
        let rect = CGRect(x: dragPlace(drag).x, y: 0, width: dragRow(drag).width, height: bounds.height)
        drag.button.frame = backingAlignedRect(rect, options: .alignAllEdgesNearest)
    }

    // Not addSubview: it takes the view out of the window for a moment, which could end the drag it's receiving.
    private func raise(_ view: NSView) {
        sortSubviews({ a, b, raised in
            if Unmanaged.passUnretained(a).toOpaque() == raised { return .orderedDescending }
            return Unmanaged.passUnretained(b).toOpaque() == raised ? .orderedAscending : .orderedSame
        }, context: Unmanaged.passUnretained(view).toOpaque())
    }

    private var layoutWidth: EntryWidth {
        settings.taskDisplay == .iconOnly
            ? entryWidth(barWidth: slot.width, entryCount: ordered.count, maxWidth: Self.iconOnlyWidth)
            : entryWidth(barWidth: slot.width, entryCount: ordered.count)
    }

    override func layout() {
        super.layout()
        launcher.frame = backingAlignedRect(CGRect(x: 0, y: 0, width: launcherWidth, height: bounds.height), options: .alignAllEdgesNearest)
        var shownIcons = pinnedIcons
        var shown = ordered
        if var drag = maybeDrag {
            let place = dragPlace(drag)
            drag.to = place.to
            maybeDrag = drag
            if drag.button is PinnedIconView {
                shownIcons.insert(shownIcons.remove(at: place.from), at: place.to)
            } else {
                shown.insert(shown.remove(at: place.from), at: place.to)
            }
            placeDragged(drag)
            // Here rather than once: a view added during the drag goes on top.
            raise(drag.button)
        }
        for (index, icon) in shownIcons.enumerated() {
            if icon === maybeDrag?.button { continue }
            let target = backingAlignedRect(CGRect(x: launcherWidth + CGFloat(index) * pinnedIconWidth, y: 0, width: pinnedIconWidth, height: bounds.height), options: .alignAllEdgesNearest)
            if icon.frame == .zero {
                icon.frame = target
            } else if icon.frame != target {
                animate { icon.animator().frame = target }
            }
        }
        let slot = self.slot
        let isIconOnlyMode = settings.taskDisplay == .iconOnly
        let layoutWidth = self.layoutWidth
        for (index, entry) in shown.enumerated() {
            entry.isIconOnly = isIconOnlyMode || layoutWidth.isIconOnly
            if entry === maybeDrag?.button { continue }
            let target = backingAlignedRect(CGRect(x: slot.x + CGFloat(index) * layoutWidth.width, y: 0, width: layoutWidth.width, height: bounds.height), options: .alignAllEdgesNearest)
            if entry.frame == .zero {
                entry.frame = target
            } else if entry.frame != target {
                manager.preview.dismiss(for: entry)
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

    @objc private func openSettings() { manager.settingsWindow.show() }

    // Backing alignment changes with the scale.
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }
}
