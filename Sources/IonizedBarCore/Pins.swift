/// The pins with `bundleID` added last; unchanged if already pinned.
public func pinning(_ bundleID: String, in pins: [String]) -> [String] {
    pins.contains(bundleID) ? pins : pins + [bundleID]
}

public func unpinning(_ bundleID: String, in pins: [String]) -> [String] {
    pins.filter { $0 != bundleID }
}

/// `shown[from]` moved to index `to` of `shown`, the pins one bar shows. Pins hidden on that bar keep their place.
public func movingPin(in pins: [String], shown: [String], from: Int, to: Int) -> [String] {
    guard shown.indices.contains(from), shown.indices.contains(to), from != to else { return pins }
    var rest = pins.filter { $0 != shown[from] }
    guard rest.count < pins.count, let anchor = rest.firstIndex(of: shown[to]) else { return pins }
    rest.insert(shown[from], at: anchor + (to > from ? 1 : 0))
    return rest
}

/// The pinned icons one bar shows, in pinning order. An uninstalled pin is hidden, not dropped from `pins`.
/// With `keepsVisible` off, an app with a task on this bar hides its icon; tasks on other bars don't.
public func visiblePins(
    _ pins: [String], keepsVisible: Bool, taskBundleIDs: Set<String>, installedBundleIDs: Set<String>
) -> [String] {
    pins.filter { installedBundleIDs.contains($0) && (keepsVisible || !taskBundleIDs.contains($0)) }
}

/// The right-click item of a task or group entry. An app with no bundle identifier has none: there is nothing to pin.
public func pinMenuTitle(bundleID: String?, pins: [String]) -> String? {
    bundleID.map { pins.contains($0) ? "Unpin" : "Pin" }
}
