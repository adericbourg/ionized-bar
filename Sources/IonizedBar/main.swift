import AppKit
@preconcurrency import ApplicationServices

// Stopgap until the M3 onboarding window: prompt once, then poll until trusted.
let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
if !AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) {
    log("Accessibility permission required; waiting for it to be granted")
}

let tracker = AppTracker(
    onLaunch: { pid in log("launch pid=\(pid) \(NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?")") },
    onTerminate: { pid in log("terminate pid=\(pid)") }
)

// Terminated apps are gone from NSRunningApplication, hence no name on terminate.
let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
    guard AXIsProcessTrusted() else { return }
    timer.invalidate()
    log("Accessibility trusted; tracking apps")
    MainActor.assumeIsolated { tracker.start() }
}
_ = timer

NSApplication.shared.run()
