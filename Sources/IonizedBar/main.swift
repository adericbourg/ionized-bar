import AppKit
@preconcurrency import ApplicationServices

// Stopgap until the M3 onboarding window: prompt once, then poll until trusted.
let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
if !AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) {
    log("Accessibility permission required; waiting for it to be granted")
}

let windowTracker = WindowTracker { windows in
    Task { @MainActor in WindowModel.update(windows, barManager: barManager) }
}

// Annotated: the tracker's closure uses barManager, which would make type inference circular.
let barManager: BarManager = BarManager(windowTracker: windowTracker)
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

let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
    guard AXIsProcessTrusted() else { return }
    timer.invalidate()
    log("Accessibility trusted; tracking apps")
    MainActor.assumeIsolated {
        tracker.start()
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            windowTracker.setFrontmost(pid: frontmost.processIdentifier)
        }
    }
    NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        MainActor.assumeIsolated { windowTracker.setFrontmost(pid: pid) }
    }
    NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
        MainActor.assumeIsolated { windowTracker.markAllDirty() }
    }
}
_ = timer

NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { barManager.sync() }
    windowTracker.markAllDirty()
}

NSApplication.shared.run()
