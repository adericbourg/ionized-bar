import AppKit

@MainActor
final class AppTracker {
    private let onLaunch: (pid_t) -> Void
    private let onTerminate: (pid_t) -> Void
    private var knownPids: Set<pid_t> = []
    private var observation: NSKeyValueObservation?

    init(onLaunch: @escaping (pid_t) -> Void, onTerminate: @escaping (pid_t) -> Void) {
        self.onLaunch = onLaunch
        self.onTerminate = onTerminate
    }

    func start() {
        // KVO rather than didLaunchApplicationNotification: not posted for LSUIElement apps.
        observation = NSWorkspace.shared.observe(\.runningApplications, options: [.initial]) { [weak self] workspace, _ in
            let pids = Set(workspace.runningApplications
                .filter { $0.activationPolicy != .prohibited && $0.processIdentifier != getpid() }
                .map(\.processIdentifier))
            MainActor.assumeIsolated { self?.update(to: pids) }
        }
    }

    private func update(to pids: Set<pid_t>) {
        let launched = pids.subtracting(knownPids)
        let terminated = knownPids.subtracting(pids)
        knownPids = pids
        launched.sorted().forEach(onLaunch)
        terminated.sorted().forEach(onTerminate)
    }
}
