import AppKit

/// The saved pins. Kept apart from `Settings`: the settings window reports a whole `Settings` and would
/// overwrite a list it doesn't edit, and pins change from menus, not from that window.
enum PinStore {
    private static let key = "pinnedBundleIDs"

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func save(_ pins: [String]) {
        UserDefaults.standard.set(pins, forKey: key)
    }
}

/// Bundle ids and install state, from the main actor (`NSRunningApplication` and `NSWorkspace` are not for the tracker thread).
@MainActor
final class AppIdentities {
    private static let installedLifetime: TimeInterval = 30
    private var installed: [String: (isInstalled: Bool, readAt: Date)] = [:]

    /// One lookup per distinct pid. A pid with no bundle id (or no longer running) is absent: it has no pin.
    func bundleIDs(of windows: [TrackedWindow]) -> [pid_t: String] {
        var result: [pid_t: String] = [:]
        for pid in Set(windows.map(\.pid)) {
            if let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier { result[pid] = id }
        }
        return result
    }

    /// `urlForApplication` hits the filesystem, so a read is kept for 30 seconds: an install or an uninstall
    /// shows within that, and a snapshot costs nothing in between.
    func installedBundleIDs(among bundleIDs: [String], now: Date = Date()) -> Set<String> {
        var result: Set<String> = []
        for id in bundleIDs {
            if installed[id].map({ now.timeIntervalSince($0.readAt) >= Self.installedLifetime }) ?? true {
                installed[id] = (NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil, now)
            }
            if installed[id]!.isInstalled { result.insert(id) }
        }
        return result
    }
}
