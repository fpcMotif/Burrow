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

    func scan() -> AsyncThrowingStream<ScanItem, any Error> {
        detachedStream { continuation in
            let home = FileManager.default.homeDirectoryForCurrentUser
            // Walk *into* matched directories so their descendants
            // contribute to the size — but emit a single `ScanItem`
            // per match by tracking the current artifact root.
            var currentArtifact: (url: URL, toolchain: String, modified: Date, bytes: Int64)?
            let walker = FSWalker(root: home) { url in
                url.lastPathComponent == ".git"
                    || url.lastPathComponent == "Library"
            }

            for try await entry in walker.entries() {
                if let artifact = currentArtifact, !entry.url.path.hasPrefix(artifact.url.path + "/") {
                    let item = ScanItem(
                        url: artifact.url,
                        size: artifact.bytes,
                        modified: artifact.modified,
                        kind: .devArtifact(toolchain: artifact.toolchain),
                        recoverable: true,
                        confidence: Self.isRepoStale(
                            parent: artifact.url.deletingLastPathComponent(),
                            staleAge: self.staleAge
                        ) ? .safe : .review
                    )
                    continuation.yield(item)
                    currentArtifact = nil
                }

                if currentArtifact == nil,
                   entry.isDirectory,
                   let toolchain = Self.toolchains[entry.url.lastPathComponent] {
                    currentArtifact = (entry.url, toolchain, entry.modified, 0)
                    continue
                }

                if currentArtifact != nil, !entry.isDirectory {
                    currentArtifact!.bytes += entry.size
                }
            }

            if let artifact = currentArtifact {
                let item = ScanItem(
                    url: artifact.url,
                    size: artifact.bytes,
                    modified: artifact.modified,
                    kind: .devArtifact(toolchain: artifact.toolchain),
                    recoverable: true,
                    confidence: Self.isRepoStale(
                        parent: artifact.url.deletingLastPathComponent(),
                        staleAge: self.staleAge
                    ) ? .safe : .review
                )
                continuation.yield(item)
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
