import Foundation

public struct InstalledApp: Sendable, Equatable {
    public let name: String
    public let url: URL
}

/// The `.app` bundles directly in each folder and in its `Utilities` subfolder (`/System/Applications/Utilities`
/// holds Terminal, Activity Monitor...), sorted by name. Blocking: call it off the main thread.
public func listApplications(in folders: [URL]) -> [InstalledApp] {
    let fileManager = FileManager.default
    var apps: [InstalledApp] = []
    for folder in folders {
        for directory in [folder, folder.appendingPathComponent("Utilities")] {
            let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
            for url in urls where url.pathExtension == "app" {
                apps.append(InstalledApp(name: url.deletingPathExtension().lastPathComponent, url: url))
            }
        }
    }
    return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

/// The items matching `query` against their name, best first: exact, prefix, word prefix, substring, one or two
/// typos (a wrong, missing, extra or swapped letter, from 4 characters), then scattered letters. An empty query
/// keeps everything in the given order.
public func fuzzyFilter<T>(_ items: [T], query: String, name: (T) -> String) -> [T] {
    let q = fold(query)
    if q.isEmpty { return items }
    let ranked: [(item: T, tier: Int, name: String)] = items.compactMap { item in
        let n = name(item)
        return tier(of: q, in: fold(n)).map { (item, $0, n) }
    }
    return ranked.sorted {
        ($0.tier, $0.name.count, $0.name) < ($1.tier, $1.name.count, $1.name)
    }.map(\.item)
}

private func fold(_ s: String) -> [Character] {
    Array(s.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))
}

private func tier(of q: [Character], in n: [Character]) -> Int? {
    if q == n { return 0 }
    if n.starts(with: q) { return 1 }
    let wordStarts = n.indices.filter { $0 == 0 || !n[$0 - 1].isLetter && !n[$0 - 1].isNumber }
    if wordStarts.contains(where: { n[$0...].starts(with: q) }) { return 2 }
    if n.indices.contains(where: { n[$0...].starts(with: q) }) { return 3 }
    let maxTypos = q.count >= 8 ? 2 : q.count >= 4 ? 1 : 0
    if maxTypos > 0, wordStarts.contains(where: { start in
        (max(1, q.count - maxTypos)...(q.count + maxTypos)).contains { length in
            start + length <= n.count && editDistance(q, Array(n[start..<start + length])) <= maxTypos
        }
    }) { return 4 }
    var rest = q[...]
    for c in n where c == rest.first { rest = rest.dropFirst() }
    return rest.isEmpty ? 5 : nil
}

/// Optimal string alignment distance: insertion, deletion, substitution and adjacent swap each cost 1.
private func editDistance(_ a: [Character], _ b: [Character]) -> Int {
    var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in 0...a.count { d[i][0] = i }
    for j in 0...b.count { d[0][j] = j }
    guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
    for i in 1...a.count {
        for j in 1...b.count {
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
            }
        }
    }
    return d[a.count][b.count]
}
