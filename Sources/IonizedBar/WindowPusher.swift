import AppKit
import IonizedBarCore

/// Decides on the main thread, where the screens are; the AX writes happen on the tracker's thread.
/// AppTracker never tracks this process, so its own windows can't get here.
@MainActor
final class WindowPusher {
    /// Not on the first absent snapshot: the Space filter can hide a window for one, and a lost entry means one more push.
    private static let forgetAfter: TimeInterval = 60
    private static let tickInterval: TimeInterval = 0.1

    private let tracker: WindowTracker
    private var memories: [AXUIElement: PushMemory] = [:]
    /// `target` is in AX coordinates, nil when the window must not be pushed.
    private var latest: [(window: TrackedWindow, target: CGRect?)] = []
    private var tick: Timer?

    init(tracker: WindowTracker) {
        self.tracker = tracker
    }

    func update(_ candidates: [(window: TrackedWindow, target: CGRect?)]) {
        latest = candidates
        evaluate()
    }

    private func evaluate() {
        tick?.invalidate()
        tick = nil
        let now = ProcessInfo.processInfo.systemUptime
        let isMouseDown = NSEvent.pressedMouseButtons != 0
        var isWaiting = false
        for (window, target) in latest {
            var memory = memories[window.element] ?? PushMemory(now: now)
            let wasAwaitingResult = memory.isAwaitingResult
            switch memory.step(frame: window.frame, wantsPush: target != nil, isMouseDown: isMouseDown, now: now) {
            case .idle:
                if wasAwaitingResult, target != nil {
                    log("\(window.appName) pid=\(window.pid) still over the bar after a push; leaving it until its frame changes")
                }
            case .wait:
                isWaiting = true
            case .push:
                isWaiting = true
                log("pushing \(window.appName) pid=\(window.pid) above the bar")
                tracker.push(window, to: target!) { [weak self] in
                    Task { @MainActor in self?.memories[window.element]?.pushWasStale() }
                }
            }
            memories[window.element] = memory
        }
        memories = memories.filter { now - $0.value.lastSeen < Self.forgetAfter }
        if isWaiting {
            // A mouse release or a frame settling posts nothing, and no snapshot would come.
            tick = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
        }
    }
}
