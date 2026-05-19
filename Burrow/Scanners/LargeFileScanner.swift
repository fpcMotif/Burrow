import Foundation

/// Emits files larger than `threshold` bytes anywhere under the home dir,
/// excluding library/caches roots (those are other scanners' jobs).
struct LargeFileScanner: Scanning {
    let id = ScannerID("large.files")
    let category: ScanCategory = .largeFiles
    let threshold: Int64

    func scan() -> AsyncThrowingStream<ScanItem, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .utility) {
                let home = FileManager.default.homeDirectoryForCurrentUser
                let pruned: Set<String> = ["Library", ".Trash", "node_modules", ".git"]
                let walker = FSWalker(root: home) { url in
                    pruned.contains(url.lastPathComponent)
                }
                do {
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
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
