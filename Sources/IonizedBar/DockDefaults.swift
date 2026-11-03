import AppKit
import IonizedBarCore

private let savedDockKey = "dockOriginals"

/// Returns the tool's output, or nil after logging a failure. Its stderr goes to the app's.
private func run(_ path: String, _ arguments: [String]) -> Data? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    let command = ([path] + arguments).joined(separator: " ")
    do {
        try process.run()
    } catch {
        log("\(command) failed to start: \(error)")
        return nil
    }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        log("\(command) failed with status \(process.terminationStatus)")
        return nil
    }
    return data
}

func killallDock() -> Bool {
    run("/usr/bin/killall", ["Dock"]) != nil
}

/// The domain, the app's defaults and the relaunch are parameters so a scratch run can stay away from the real Dock.
func defaultsDockStore(domain: String, savedIn appDefaults: UserDefaults, relaunchDock: @escaping () -> Bool) -> DockStore {
    func read() -> DockPrefs? {
        // Export rather than `defaults read`: an absent key is then told from a failure without parsing error messages.
        guard let plist = run("/usr/bin/defaults", ["export", domain, "-"]) else { return nil }
        guard let prefs = parseDockPrefs(plist: plist) else {
            log("Unexpected values in \(domain)")
            return nil
        }
        return prefs
    }
    func apply(key: String, type: String, value: String?, isPresent: Bool) -> Bool {
        if let value {
            return run("/usr/bin/defaults", ["write", domain, key, type, value]) != nil
        }
        // Deleting an absent key is an error, which would block a retry after a partial restore.
        return !isPresent || run("/usr/bin/defaults", ["delete", domain, key]) != nil
    }
    return DockStore(
        read: read,
        write: { prefs in
            // Read only when a key needs deleting: a failed read must not block restoring values.
            var current = prefs
            if prefs.autohide == nil || prefs.autohideDelay == nil {
                guard let read = read() else { return false }
                current = read
            }
            // Both keys are always tried, so one failing doesn't leave the other unrestored.
            let isAutohideOK = apply(key: DockPrefs.autohideKey, type: "-bool", value: prefs.autohide.map { String($0) }, isPresent: current.autohide != nil)
            let isDelayOK = apply(key: DockPrefs.autohideDelayKey, type: "-float", value: prefs.autohideDelay.map { String($0) }, isPresent: current.autohideDelay != nil)
            return isAutohideOK && isDelayOK
        },
        relaunchDock: relaunchDock,
        loadSaved: { appDefaults.dictionary(forKey: savedDockKey).flatMap(DockPrefs.init(dictionary:)) },
        save: { prefs in
            appDefaults.set(prefs.dictionary, forKey: savedDockKey)
            // Writes otherwise reach disk later: a crash right after hiding would lose the originals.
            return appDefaults.synchronize()
        },
        clearSaved: {
            appDefaults.removeObject(forKey: savedDockKey)
            appDefaults.synchronize()
        },
        log: log
    )
}

@MainActor private var signalSources: [DispatchSourceSignal] = []

/// Runs on a normal quit and on SIGTERM and SIGINT. `kill -9` can't be caught: the next launch recovers from the saved state.
@MainActor func restoreDockOnTermination(_ restore: @escaping @MainActor () -> Void) {
    // No queue: the block runs inside the post, so the restore is done before the process exits.
    NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in
        MainActor.assumeIsolated { restore() }
    }
    for signalNumber in [SIGTERM, SIGINT] {
        signal(signalNumber, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { NSApplication.shared.terminate(nil) }
        }
        source.resume()
        signalSources.append(source)
    }
}
