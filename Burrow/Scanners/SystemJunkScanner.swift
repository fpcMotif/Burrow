import Foundation

/// User-space caches and log archives. Safe to wipe — apps regenerate
/// them on next launch.
struct SystemJunkScanner: Scanning {
    let category: ScanCategory = .systemJunk

    func scan() -> AsyncThrowingStream<ScanItem, any Error> {
        detachedStream { continuation in
            for root in Self.roots() {
                let walker = FSWalker(root: root)
                do {
                    for try await entry in walker.entries() where !entry.isDirectory {
                        continuation.yield(ScanItem(
                            url: entry.url,
                            size: entry.size,
                            modified: entry.modified,
                            kind: .cache,
                            recoverable: true,
                            confidence: .safe
                        ))
                    }
                } catch is CancellationError {
                    return
                } catch {
                    // Tolerate per-root errors (TCC denials etc.) and move on
                    // to the next root rather than failing the whole scan.
                }
            }
        }
    }

    /// Roots we consider "system junk". Conservative on purpose — we
    /// never touch system-owned `/Library/Caches` from the sandboxed
    /// process; the helper does that.
    private static func roots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appending(path: "Library/Caches", directoryHint: .isDirectory),
            home.appending(path: "Library/Logs", directoryHint: .isDirectory),
        ]
    }
}
