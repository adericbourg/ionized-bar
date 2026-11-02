import AppKit
import IonizedBarCore

final class BarContentView: NSView {
    private let actions: EntryActions
    private var entries: [AXUIElement: EntryView] = [:]
    private var ordered: [EntryView] = []
    // Entries fading out; one is revived if its window returns before the fade ends.
    private var leaving: [AXUIElement: EntryView] = [:]
    private var settings = Settings.load()

    private static let duration: TimeInterval = 0.12
    private static let iconOnlyWidth: CGFloat = 48
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
        self.settings = settings
        var gone = entries
        ordered = windows.map { window in
            let entry = entries[window.element] ?? revive(window.element) ?? addEntry(window)
            entries[window.element] = entry
            gone[window.element] = nil
            entry.update(with: window, display: settings.taskDisplay)
            return entry
        }
        for (element, entry) in gone {
            entries[element] = nil
            leaving[element] = entry
            animate({ entry.animator().alphaValue = 0 }) { [weak self] in
                MainActor.assumeIsolated { self?.finishLeaving(entry) }
            }
        }
        needsLayout = true
    }

    private func addEntry(_ window: TrackedWindow) -> EntryView {
        let entry = EntryView(window: window, actions: actions)
        entry.alphaValue = 0
        addSubview(entry)
        animate { entry.animator().alphaValue = 1 }
        return entry
    }

    private func finishLeaving(_ entry: EntryView) {
        guard let element = leaving.first(where: { $0.value === entry })?.key else { return }
        entry.removeFromSuperview()
        leaving[element] = nil
    }

    private func revive(_ element: AXUIElement) -> EntryView? {
        guard let entry = leaving.removeValue(forKey: element) else { return nil }
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
