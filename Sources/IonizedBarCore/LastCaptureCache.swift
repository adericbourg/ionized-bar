/// The last captured value per key, in memory only. Keep it to the open windows with `keepOnly`, which bounds it.
public struct LastCaptureCache<Key: Hashable, Value> {
    private var values: [Key: Value] = [:]

    public init() {}

    public mutating func store(_ value: Value, for key: Key) { values[key] = value }

    public func value(for key: Key) -> Value? { values[key] }

    public mutating func keepOnly(_ keys: Set<Key>) { values = values.filter { keys.contains($0.key) } }
}
