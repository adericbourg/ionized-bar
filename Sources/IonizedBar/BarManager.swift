import AppKit
import IonizedBarCore

@MainActor
final class BarManager {
    let launcher = LauncherController()
    let calendar = CalendarController()
    // The one place a capture is asked for, always after `EntryView.previewWindow` checks the setting and the grant.
    private(set) lazy var preview = PreviewController { [unowned self] in await thumbnail(of: $0) }
    // Memory only, never on disk. A minimized window can't be captured (-3811), so it shows its last image.
    private var lastCaptures: [AXUIElement: CGImage] = [:]
    let windowTracker: WindowTracker
    let settingsWindow: SettingsWindow
    private var panels: [UInt32: BarPanel] = [:]
    private(set) var settings = Settings.load()
    private var latestWindowsByDisplay: [UInt32: [TrackedWindow]] = [:]
    // Across all bars, memory only: AX elements don't survive a restart.
    private var taskOrder = TaskOrder<AXUIElement>()
    // Apart from `Settings`: the settings window reports a whole `Settings` and would overwrite a list it doesn't edit.
    private static let pinsKey = "pinnedBundleIDs"
    private(set) var pins = UserDefaults.standard.stringArray(forKey: BarManager.pinsKey) ?? []

    init(windowTracker: WindowTracker) {
        self.windowTracker = windowTracker
        let settingsWindow = SettingsWindow(settings: settings)
        self.settingsWindow = settingsWindow
        // The settings window knows nothing of previews, so keep their current value.
        settingsWindow.onChange = { [weak self] in
            guard let self else { return }
            var newSettings = $0
            newSettings.showsPreviews = settings.showsPreviews
            apply(newSettings)
        }
        // Read-only status: no prompt. Only the opt-in toggle may ask.
        if settings.showsPreviews { log("screen recording \(CGPreflightScreenCaptureAccess() ? "granted" : "not granted")") }
    }

    func sync() {
        preview.dismiss()
        launcher.close()
        calendar.close()
        var current: [UInt32: NSScreen] = [:]
        for screen in NSScreen.screens {
            if let id = screen.displayID { current[id] = screen }
        }
        for id in panels.keys where current[id] == nil {
            panels.removeValue(forKey: id)?.close()
        }
        for (id, screen) in current {
            let frame = barFrame(screenFrame: screen.frame, height: settings.barHeight.points)
            if let panel = panels[id] {
                panel.setFrame(frame, display: true)
            } else {
                let panel = BarPanel(frame: frame, manager: self)
                panels[id] = panel
                panel.orderFrontRegardless()
            }
        }
        updateJointAreas()
        // Pinned icons need no window: without this a new bar shows none until the first snapshot.
        update(windowsByDisplay: latestWindowsByDisplay)
    }

    func beginKeyboardMode() {
        let mouse = NSEvent.mouseLocation
        guard let id = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })?.displayID else { return }
        panels[id]?.beginKeyboardMode()
    }

    var showsPreviews: Bool { settings.showsPreviews }

    func setShowsPreviews(_ isOn: Bool) {
        var newSettings = settings
        newSettings.showsPreviews = isOn
        apply(newSettings)
    }

    /// Previews are on and Screen Recording is granted. Asked afresh each time: the grant can change while the app runs.
    /// Preflight never prompts, and the setting comes first so that with previews off it isn't called.
    var canPreview: Bool { settings.showsPreviews && !launcher.isOpen && !calendar.isOpen && CGPreflightScreenCaptureAccess() }

    func setPins(_ newPins: [String]) {
        pins = newPins
        UserDefaults.standard.set(newPins, forKey: BarManager.pinsKey)
        update(windowsByDisplay: latestWindowsByDisplay)
    }

    func openPinnedApp(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            log("Could not open \(bundleID): not installed")
            return
        }
        BarManager.openApp(at: url)
    }

    /// Moves `items[from]` to index `to`, `items` being the bar's current entries.
    func moveEntry(_ items: [BarItem<TrackedWindow>], from: Int, to: Int) {
        taskOrder.move(items, from: from, to: to, key: \.element)
        update(windowsByDisplay: latestWindowsByDisplay)
    }

    static func openApp(at url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, maybeError in
            if let maybeError { log("Could not open \(url.lastPathComponent): \(maybeError.localizedDescription)") }
        }
    }

    private func thumbnail(of window: TrackedWindow) async -> CGImage? {
        if !window.isMinimized, let image = await PreviewCapture.thumbnail(pid: window.pid, frame: window.frame) {
            lastCaptures[window.element] = image
            return image
        }
        return lastCaptures[window.element]
    }

    func update(windowsByDisplay: [UInt32: [TrackedWindow]], aliveWindows: Set<AXUIElement>) {
        // By `order`: new windows go last in the order given here, and the dictionary's is arbitrary.
        let seen = windowsByDisplay.values.joined().sorted { $0.order < $1.order }.map(\.element)
        taskOrder.update(seen: seen, alive: aliveWindows)
        update(windowsByDisplay: windowsByDisplay)
    }

    private func update(windowsByDisplay: [UInt32: [TrackedWindow]]) {
        latestWindowsByDisplay = windowsByDisplay
        let shown = Set(windowsByDisplay.values.joined().map(\.element))
        lastCaptures = lastCaptures.filter { shown.contains($0.key) }
        let installed = Set(pins.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil })
        for (id, panel) in panels {
            let windows = taskOrder.sorted(windowsByDisplay[id] ?? [], key: \.element)
            // Every window on the bar counts, so a group entry hides its app's icon too.
            let shownPins = visiblePins(
                pins, keepsVisible: settings.keepsPinnedVisible,
                taskBundleIDs: Set(windows.compactMap { NSRunningApplication(processIdentifier: $0.pid)?.bundleIdentifier }), installedBundleIDs: installed
            )
            panel.update(with: windows, settings: settings, pins: shownPins)
        }
    }

    private func apply(_ newSettings: Settings) {
        let isEnablingPreviews = newSettings.showsPreviews && !settings.showsPreviews
        let isResizing = newSettings.barHeight != settings.barHeight
        settings = newSettings
        if !settings.showsPreviews { preview.dismiss() }
        if isEnablingPreviews { CGRequestScreenCaptureAccess() }
        settings.save()
        if isResizing {
            // Resizes every bar, then updates the joint areas and the bars' content.
            sync()
        } else {
            updateJointAreas()
            update(windowsByDisplay: latestWindowsByDisplay)
        }
    }

    private func updateJointAreas() {
        guard settings.resizesJointWindows, let primary = NSScreen.screens.first else {
            windowTracker.setJointAreas([])
            return
        }
        windowTracker.setJointAreas(NSScreen.screens.map {
            flipRect(usableArea(screenFrame: $0.frame, visibleFrame: $0.visibleFrame, barHeight: settings.barHeight.points), primaryScreenHeight: primary.frame.height)
        })
    }
}
