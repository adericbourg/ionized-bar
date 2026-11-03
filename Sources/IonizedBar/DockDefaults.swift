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

func defaultsDockStore() -> DockStore {
    let appDefaults = UserDefaults.standard
    let dockDomain = "com.apple.dock" as CFString
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
