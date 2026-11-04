import AppKit
@preconcurrency import ApplicationServices
import IonizedBarCore

// What LSUIElement does in the bundle; a bare `swift run` binary has no Info.plist and would stay .prohibited,
// so no regular window (Settings, onboarding) could show.
NSApplication.shared.setActivationPolicy(.accessory)

let windowTracker = WindowTracker { windows, aliveWindows in
    Task { @MainActor in WindowModel.update(windows, aliveWindows: aliveWindows, barManager: barManager, pusher: windowPusher) }
}

// Annotated: the tracker's closure uses barManager, which would make type inference circular.
let barManager: BarManager = BarManager(windowTracker: windowTracker)
let windowPusher: WindowPusher = WindowPusher(tracker: windowTracker)
barManager.sync()
BarHotKey.register { barManager.beginKeyboardMode() }

let tracker = AppTracker(
    onLaunch: { pid in
        log("launch pid=\(pid) \(NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?")")
        windowTracker.addApp(pid: pid)
    },
    onTerminate: { pid in
        // Terminated apps are gone from NSRunningApplication, hence no name on terminate.
        log("terminate pid=\(pid)")
        windowTracker.removeApp(pid: pid)
    }
)

let dockLock = openDockLock()
dockLock?.hold()
let dock = defaultsDockStore(lock: dockLock)
restoreDockOnTermination { restoreDock(dock) }

// The one place that runs once Accessibility is granted, on the main thread.
@MainActor func onAccessibilityTrusted() {
    log("Accessibility trusted; tracking apps")
    tracker.start()
    if let frontmost = NSWorkspace.shared.frontmostApplication {
        windowTracker.setFrontmost(pid: frontmost.processIdentifier)
    }
    NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        MainActor.assumeIsolated { windowTracker.setFrontmost(pid: pid) }
    }
    NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
        MainActor.assumeIsolated { windowTracker.markAllDirty() }
    }
    log(hideDock(dock) ? "Dock hidden" : "Dock not hidden")
    LoginItem.registerOnce()
}

let onboardingWindow = OnboardingWindow()
if AXIsProcessTrusted() {
    onAccessibilityTrusted()
} else {
    log("Accessibility permission required; waiting for it to be granted")
    // After a crash with the permission lost (each upgrade loses it), the Dock would stay hidden above an empty bar.
    restoreDock(dock)
    // The restore's check gave up the lock, and this copy keeps running.
    dockLock?.hold()
    onboardingWindow.show()
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
        guard AXIsProcessTrusted() else { return }
        timer.invalidate()
        MainActor.assumeIsolated {
            onboardingWindow.close()
            onAccessibilityTrusted()
        }
    }
}

NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { barManager.sync() }
    windowTracker.markAllDirty()
}

NSApplication.shared.run()
