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
        canPreview: { [unowned self] in settings.showsPreviews && CGPreflightScreenCaptureAccess() },
        preview: preview
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
    }

    func beginKeyboardMode() {
        let mouse = NSEvent.mouseLocation
        guard let id = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })?.displayID else { return }
        panels[id]?.beginKeyboardMode()
    }

    private func thumbnail(of window: TrackedWindow) async -> CGImage? {
        if !window.isMinimized, let image = await PreviewCapture.thumbnail(pid: window.pid, frame: window.frame) {
            lastCaptures.store(image, for: window.element)
            return image
        }
        return lastCaptures.value(for: window.element)
    }

    func update(windowsByDisplay: [UInt32: [TrackedWindow]]) {
        latestWindowsByDisplay = windowsByDisplay
        lastCaptures.keepOnly(Set(windowsByDisplay.values.joined().map(\.element)))
        for (id, panel) in panels {
            panel.update(with: windowsByDisplay[id] ?? [], settings: settings)
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
