import AppKit
import IonizedBarCore

private let savedDockKey = "dockOriginals"

func killallDock() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
    process.arguments = ["Dock"]
    do {
        try process.run()
    } catch {
        log("killall Dock failed to start: \(error)")
        return false
    }
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        log("killall Dock failed with status \(process.terminationStatus)")
        return false
    }
    return true
}

/// In Application Support, as macOS purges old files from the temporary directory, and a copy opening a new file wouldn't see the running one.
func openDockLock() -> DockLock? {
    do {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("IonizedBar")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let lock = DockLock(path: directory.appendingPathComponent("dock.lock").path) else {
            log("Dock lock file failed to open")
            return nil
        }
        return lock
    } catch {
        log("Dock lock directory failed: \(error)")
        return nil
    }
}

func defaultsDockStore(lock: DockLock?) -> DockStore {
    let dockDomain = "com.apple.dock" as CFString
    // Fixed, not the process's own domain: a `swift run` build has a different one and would miss the installed app's saved state.
    let appDomain = "io.github.adericbourg.ionized-bar" as CFString
    return DockStore(
        read: {
            // Picks up what another process wrote since the last read.
            CFPreferencesAppSynchronize(dockDomain)
            var dictionary: [String: Any] = [:]
            for key in [DockPrefs.autohideKey, DockPrefs.autohideDelayKey] {
                dictionary[key] = CFPreferencesCopyAppValue(key as CFString, dockDomain)
            }
            guard let prefs = DockPrefs(dictionary: dictionary) else {
                log("Unexpected values in \(dockDomain)")
                return nil
            }
            return prefs
        },
        write: { prefs in
            // A nil value deletes the key, and deleting an absent key is fine.
            CFPreferencesSetAppValue(DockPrefs.autohideKey as CFString, prefs.autohide.map { $0 as CFBoolean }, dockDomain)
            CFPreferencesSetAppValue(DockPrefs.autohideDelayKey as CFString, prefs.autohideDelay.map { $0 as CFNumber }, dockDomain)
            return CFPreferencesAppSynchronize(dockDomain)
        },
        relaunchDock: killallDock,
        loadSaved: {
            // Picks up what another copy wrote since the last read.
            CFPreferencesAppSynchronize(appDomain)
            let saved = CFPreferencesCopyAppValue(savedDockKey as CFString, appDomain) as? [String: Any]
            return saved.flatMap(DockPrefs.init(dictionary:))
        },
        save: { prefs in
            CFPreferencesSetAppValue(savedDockKey as CFString, prefs.dictionary as CFDictionary, appDomain)
            // Writes otherwise reach disk later: a crash right after hiding would lose the originals.
            return CFPreferencesAppSynchronize(appDomain)
        },
        clearSaved: {
            CFPreferencesSetAppValue(savedDockKey as CFString, nil, appDomain)
            CFPreferencesAppSynchronize(appDomain)
        },
        isOtherCopyRunning: { lock?.isOtherCopyRunning() ?? false },
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
