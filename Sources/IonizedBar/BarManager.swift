import AppKit
import IonizedBarCore

@MainActor
final class BarManager {
    private lazy var actions = EntryActions(
        raise: windowTracker.raise, minimize: windowTracker.minimize, restore: windowTracker.restore, close: windowTracker.close,
        openSettings: settingsWindow.show,
        showsPreviews: { [unowned self] in settings.showsPreviews },
        setShowsPreviews: { [unowned self] in
            var newSettings = settings
            newSettings.showsPreviews = $0
            apply(newSettings)
        },
        // Preflight never prompts, and the setting comes first so that with previews off it isn't called.
        canPreview: { [unowned self] in settings.showsPreviews && !launcher.isOpen && CGPreflightScreenCaptureAccess() },
        preview: preview,
        openLauncher: { [unowned self] in launcher.toggle(above: $0) },
        bundleID: { [unowned self] in identities.bundleIDs(of: [$0])[$0.pid] },
        pins: { [unowned self] in pins },
        setPins: { [unowned self] in
            pins = $0
            PinStore.save($0)
            update(windowsByDisplay: latestWindowsByDisplay)
        },
        openPinnedApp: { bundleID in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                log("Could not open \(bundleID): not installed")
                return
            }
            BarManager.openApp(at: url)
        },
        moveEntry: { [unowned self] items, from, to in
            taskOrder.move(items, from: from, to: to, key: \.element)
            update(windowsByDisplay: latestWindowsByDisplay)
        }
    )
    private lazy var launcher = LauncherController(
        listApps: {
            listApplications(in: ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"].map { URL(fileURLWithPath: $0) })
        },
        openApp: { BarManager.openApp(at: $0) }
    )
    // The one place a capture is asked for, always after `EntryView.previewWindow` checks the setting and the grant.
    private lazy var preview = PreviewController { [unowned self] in await thumbnail(of: $0) }
    // Memory only, never on disk. A minimized window can't be captured (-3811), so it shows its last image.
    private var lastCaptures = LastCaptureCache<AXUIElement, CGImage>()
    private let windowTracker: WindowTracker
    private let settingsWindow: SettingsWindow
    private var panels: [UInt32: BarPanel] = [:]
    private var settings = Settings.load()
    private var latestWindowsByDisplay: [UInt32: [TrackedWindow]] = [:]
    // Across all bars, memory only: AX elements don't survive a restart.
    private var taskOrder = TaskOrder<AXUIElement>()
    private var pins = PinStore.load()
    private let identities = AppIdentities()

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
        var current: [UInt32: NSScreen] = [:]
        for screen in NSScreen.screens {
            if let id = screen.displayID { current[id] = screen }
        }
        for id in panels.keys where current[id] == nil {
            panels.removeValue(forKey: id)?.close()
        }
        for (id, screen) in current {
            let frame = barFrame(screenFrame: screen.frame)
            if let panel = panels[id] {
                panel.setFrame(frame, display: true)
            } else {
                let panel = BarPanel(frame: frame, actions: actions)
                panels[id] = panel
                panel.orderFrontRegardless()
            }
        }
        // Pinned icons need no window: without this a new bar shows none until the first snapshot.
        update(windowsByDisplay: latestWindowsByDisplay)
    }

    func beginKeyboardMode() {
        let mouse = NSEvent.mouseLocation
        guard let id = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })?.displayID else { return }
        panels[id]?.beginKeyboardMode()
    }

    private static func openApp(at url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, maybeError in
            if let maybeError { log("Could not open \(url.lastPathComponent): \(maybeError.localizedDescription)") }
        }
    }

    private func thumbnail(of window: TrackedWindow) async -> CGImage? {
        if !window.isMinimized, let image = await PreviewCapture.thumbnail(pid: window.pid, frame: window.frame) {
            lastCaptures.store(image, for: window.element)
            return image
        }
        return lastCaptures.value(for: window.element)
    }

    func update(windowsByDisplay: [UInt32: [TrackedWindow]], aliveWindows: Set<AXUIElement>) {
        // By `order`: new windows go last in the order given here, and the dictionary's is arbitrary.
        let seen = windowsByDisplay.values.joined().sorted { $0.order < $1.order }.map(\.element)
        taskOrder.update(seen: seen, alive: aliveWindows)
        update(windowsByDisplay: windowsByDisplay)
    }

    private func update(windowsByDisplay: [UInt32: [TrackedWindow]]) {
        latestWindowsByDisplay = windowsByDisplay
        lastCaptures.keepOnly(Set(windowsByDisplay.values.joined().map(\.element)))
        let bundleIDs = identities.bundleIDs(of: Array(windowsByDisplay.values.joined()))
        let installed = identities.installedBundleIDs(among: pins)
        for (id, panel) in panels {
            let windows = taskOrder.sorted(windowsByDisplay[id] ?? [], key: \.element)
            // Every window on the bar counts, so a group entry hides its app's icon too.
            let shownPins = visiblePins(
                pins, keepsVisible: settings.keepsPinnedVisible,
                taskBundleIDs: Set(windows.compactMap { bundleIDs[$0.pid] }), installedBundleIDs: installed
            )
            panel.update(with: windows, settings: settings, pins: shownPins)
        }
    }

    private func apply(_ newSettings: Settings) {
        let isEnablingPreviews = newSettings.showsPreviews && !settings.showsPreviews
        settings = newSettings
        if !settings.showsPreviews { preview.dismiss() }
        if isEnablingPreviews { CGRequestScreenCaptureAccess() }
        settings.save()
        update(windowsByDisplay: latestWindowsByDisplay)
    }
}
