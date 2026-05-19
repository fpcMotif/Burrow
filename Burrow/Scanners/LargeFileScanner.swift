import Foundation

/// Emits files larger than `threshold` bytes anywhere under the home dir,
/// excluding library/caches roots (those are other scanners' jobs).
struct LargeFileScanner: Scanning {
    let category: ScanCategory = .largeFiles
    let threshold: Int64

    /// Pruned at any depth — these names are reliably "noise" wherever
    /// they appear in a tree (build artifacts, version control, trash).
    private static let prunedAnywhere: Set<String> = ["node_modules", ".git", ".Trash"]

    /// Only pruned when they sit directly under $HOME. `Library` deep
    /// inside a project folder (e.g. an SPM-shipped resource bundle) is
    /// fair game.
    private static let prunedAtHomeRoot: Set<String> = ["Library"]

    func scan() -> AsyncThrowingStream<ScanItem, any Error> {
        detachedStream { continuation in
            let home = FileManager.default.homeDirectoryForCurrentUser
            let homePath = home.path
            let walker = FSWalker(root: home) { url in
                if Self.prunedAnywhere.contains(url.lastPathComponent) { return true }
                if Self.prunedAtHomeRoot.contains(url.lastPathComponent),
                   url.deletingLastPathComponent().path == homePath {
                    return true
                }
                return false
            }
            for try await entry in walker.entries()
                where !entry.isDirectory && entry.size >= self.threshold
            {
                continuation.yield(ScanItem(
                    url: entry.url,
                    size: entry.size,
                    modified: entry.modified,
                    kind: .largeFile,
                    recoverable: true,
                    confidence: .review
                ))
            }
        }
    }
}
