import AppKit
@preconcurrency import ApplicationServices

// Stopgap until the M3 onboarding window: prompt once, then poll until trusted.
let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
if !AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) {
    log("Accessibility permission required; waiting for it to be granted")
}

let windowTracker = WindowTracker { windows in
    log("snapshot: \(windows.count) windows")
    for window in windows {
        log("  pid=\(window.pid) \(window.appName) \"\(window.title)\" \(window.frame) minimized=\(window.isMinimized) focused=\(window.isFocused)")
    }
}

let tracker = AppTracker(
    onLaunch: { pid in
        log("launch pid=\(pid) \(NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?")")
        windowTracker.addApp(pid: pid)
    },
    onTerminate: { pid in
        log("terminate pid=\(pid)")
        windowTracker.removeApp(pid: pid)
    }
)

// Terminated apps are gone from NSRunningApplication, hence no name on terminate.
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

NSApplication.shared.run()
