public func versionDescription(version: String?, commit: String?) -> String {
    guard let version else { return "development build" }
    guard let commit else { return version }
    return "\(version) (\(commit))"
}
