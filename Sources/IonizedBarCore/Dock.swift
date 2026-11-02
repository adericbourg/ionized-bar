import Foundation

/// Values of `com.apple.dock`; nil means the key is absent, so restoring deletes it.
public struct DockPrefs: Equatable, Sendable {
    public var autohide: Bool?
    public var autohideDelay: Double?

    public init(autohide: Bool?, autohideDelay: Double?) {
        self.autohide = autohide
        self.autohideDelay = autohideDelay
    }

    public static let hidden = DockPrefs(autohide: true, autohideDelay: 1000)

    /// Nobody picks a delay this long, so it was left by another taskbar or by a lost saved state. Well below `hidden`, well above a real preference.
    public static let leftoverDelayThreshold: Double = 60

    public static let autohideKey = "autohide"
    public static let autohideDelayKey = "autohide-delay"

    /// Nil when a key holds something other than a number.
    public init?(dictionary: [String: Any]) {
        let autohide = dictionary[Self.autohideKey]
        let autohideDelay = dictionary[Self.autohideDelayKey]
        guard autohide == nil || autohide is NSNumber, autohideDelay == nil || autohideDelay is NSNumber else { return nil }
        self.autohide = (autohide as? NSNumber)?.boolValue
        self.autohideDelay = (autohideDelay as? NSNumber)?.doubleValue
    }

    public var dictionary: [String: Any] {
        var dictionary: [String: Any] = [:]
        dictionary[Self.autohideKey] = autohide
        dictionary[Self.autohideDelayKey] = autohideDelay
        return dictionary
    }
}

public struct DockStore {
    /// Nil when the read failed, which is not the same as both keys being absent.
    public var read: () -> DockPrefs?
    public var write: (DockPrefs) -> Bool
    public var relaunchDock: () -> Bool
    public var loadSaved: () -> DockPrefs?
    public var save: (DockPrefs) -> Bool
    public var clearSaved: () -> Void
    public var log: (String) -> Void

    public init(read: @escaping () -> DockPrefs?, write: @escaping (DockPrefs) -> Bool, relaunchDock: @escaping () -> Bool,
                loadSaved: @escaping () -> DockPrefs?, save: @escaping (DockPrefs) -> Bool, clearSaved: @escaping () -> Void,
                log: @escaping (String) -> Void) {
        self.read = read
        self.write = write
        self.relaunchDock = relaunchDock
        self.loadSaved = loadSaved
        self.save = save
        self.clearSaved = clearSaved
        self.log = log
    }
}

public func hideDock(_ store: DockStore) -> Bool {
    // Saved originals here mean the last run crashed: the Dock still has the hidden values, so reading it again would lose the real ones.
    if store.loadSaved() == nil {
        guard var originals = store.read() else { return false }
        if let delay = originals.autohideDelay, delay >= DockPrefs.leftoverDelayThreshold {
            // Saving these would make the restore keep the Dock hidden for good.
            store.log("Dock autohide-delay of \(delay)s is a leftover, not a preference; the Dock will be left visible on quit")
            originals = DockPrefs(autohide: nil, autohideDelay: nil)
        }
        guard store.save(originals) else { return false }
    }
    guard store.write(.hidden) else { return false }
    return store.relaunchDock()
}

public func restoreDock(_ store: DockStore) {
    guard let originals = store.loadSaved() else { return }
    let isWritten = store.write(originals)
    // Even after a failed write: one of the two keys may have been written.
    _ = store.relaunchDock()
    if isWritten { store.clearSaved() }
}

/// Parses `defaults export` output. Nil when it can't be trusted, so the caller doesn't take a failure for absent keys.
public func parseDockPrefs(plist: Data) -> DockPrefs? {
    guard let dictionary = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any] else { return nil }
    return DockPrefs(dictionary: dictionary)
}
