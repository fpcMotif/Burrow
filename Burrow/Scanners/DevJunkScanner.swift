import Foundation

/// Detects build artifacts that any developer machine accumulates:
/// `node_modules`, `target`, `.venv`, `.build`, `DerivedData`, etc.
///
/// Differentiator vs Mole: we parse the *adjacent* lockfile to decide
/// whether the artifact still belongs to an actively-developed repo
/// (last git commit < `staleAge`). Fresh repos get a "review" badge;
/// stale ones are flagged "safe".
struct DevJunkScanner: Scanning {
    let category: ScanCategory = .devJunk

    /// `lastPathComponent` → toolchain. Hash lookup keeps the walker's
    /// per-directory check O(1) instead of scanning the signatures array.
    private static let toolchains: [String: String] = [
        "node_modules": "node",
        ".venv": "python",
        "venv": "python",
        "__pycache__": "python",
        "target": "rust",
        ".build": "swift",
        "DerivedData": "xcode",
        "Pods": "cocoapods",
        ".next": "node",
        ".turbo": "node",
        "dist": "node",
        "build": "generic",
        ".gradle": "gradle",
    ]

    /// A repo whose HEAD is older than this is "stale" and its artifacts
    /// are safe to nuke without warning.
    private let staleAge: TimeInterval = 30 * 24 * 60 * 60

    /// In-flight accumulator while the walker is descending into a
    /// matched directory; flushed to a `ScanItem` once we leave the
    /// subtree (or the walk finishes).
    private struct Pending {
        let url: URL
        let toolchain: String
        let modified: Date
        var bytes: Int64

        func makeItem(staleAge: TimeInterval) -> ScanItem {
            let confidence: ScanItem.Confidence =
                DevJunkScanner.isRepoStale(parent: url.deletingLastPathComponent(), staleAge: staleAge)
                ? .safe : .review
            return ScanItem(
                url: url,
                size: bytes,
                modified: modified,
                kind: .devArtifact(toolchain: toolchain),
                recoverable: true,
                confidence: confidence
            )
        }
    }

    func scan() -> AsyncThrowingStream<ScanItem, any Error> {
        let staleAge = self.staleAge
        return detachedStream { continuation in
            let home = FileManager.default.homeDirectoryForCurrentUser
            // Walk *into* matched directories so their descendants
            // contribute to the size — but emit a single `ScanItem`
            // per match by tracking the current artifact root.
            var pending: Pending?
            let walker = FSWalker(root: home) { url in
                url.lastPathComponent == ".git"
                    || url.lastPathComponent == "Library"
            }

            for try await entry in walker.entries() {
                if let active = pending, !entry.url.path.hasPrefix(active.url.path + "/") {
                    continuation.yield(active.makeItem(staleAge: staleAge))
                    pending = nil
                }

                if pending == nil,
                   entry.isDirectory,
                   let toolchain = Self.toolchains[entry.url.lastPathComponent] {
                    pending = Pending(url: entry.url, toolchain: toolchain, modified: entry.modified, bytes: 0)
                    continue
                }

                if pending != nil, !entry.isDirectory {
                    pending!.bytes += entry.size
                }
            }

            if let active = pending {
                continuation.yield(active.makeItem(staleAge: staleAge))
            }
        }
    }

    private static func isRepoStale(parent: URL, staleAge: TimeInterval) -> Bool {
        let head = parent.appending(path: ".git/HEAD")
        guard let mtime = try? head.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        else { return true } // no git at all → safe by default
        return Date.now.timeIntervalSince(mtime) > staleAge
    }
}
