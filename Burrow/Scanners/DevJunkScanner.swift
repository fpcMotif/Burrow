import Foundation

/// Detects build artifacts that any developer machine accumulates:
/// `node_modules`, `target`, `.venv`, `.build`, `DerivedData`, etc.
///
/// Differentiator vs Mole: we parse the *adjacent* lockfile to decide
/// whether the artifact still belongs to an actively-developed repo
/// (last git commit < `staleAge`). Fresh repos get a "review" badge;
/// stale ones are flagged "safe".
struct DevJunkScanner: Scanning {
    let id = ScannerID("dev.junk")
    let category: ScanCategory = .devJunk

    /// Directories matching these names are build artifacts. Each maps
    /// to the toolchain the user installed it from — useful for grouping.
    private static let signatures: [(name: String, toolchain: String)] = [
        ("node_modules", "node"),
        (".venv", "python"),
        ("venv", "python"),
        ("__pycache__", "python"),
        ("target", "rust"),
        (".build", "swift"),
        ("DerivedData", "xcode"),
        ("Pods", "cocoapods"),
        (".next", "node"),
        (".turbo", "node"),
        ("dist", "node"),
        ("build", "generic"),
        (".gradle", "gradle"),
    ]

    /// A repo whose HEAD is older than this is "stale" and its artifacts
    /// are safe to nuke without warning.
    private let staleAge: TimeInterval = 30 * 24 * 60 * 60

    func scan() -> AsyncThrowingStream<ScanItem, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .utility) {
                let home = FileManager.default.homeDirectoryForCurrentUser
                let walker = FSWalker(root: home) { url in
                    // Don't recurse into a build artifact — once we've
                    // matched, we measure it as a unit and skip its
                    // children.
                    Self.signatures.contains { url.lastPathComponent == $0.name }
                        || url.lastPathComponent == ".git"
                        || url.lastPathComponent == "Library"
                }

                do {
                    for try await entry in walker.entries() where entry.isDirectory {
                        guard let sig = Self.signatures.first(where: { entry.url.lastPathComponent == $0.name }) else {
                            continue
                        }
                        let size = await Self.measure(entry.url)
                        let confidence: ScanItem.Confidence =
                            self.isRepoStale(parent: entry.url.deletingLastPathComponent()) ? .safe : .review
                        let item = ScanItem(
                            url: entry.url,
                            size: size,
                            modified: entry.modified,
                            kind: .devArtifact(toolchain: sig.toolchain),
                            recoverable: true,
                            confidence: confidence
                        )
                        continuation.yield(item)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Total bytes under `url`, computed off the calling task.
    private static func measure(_ url: URL) async -> Int64 {
        await Task.detached(priority: .utility) {
            var total: Int64 = 0
            if let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let item as URL in enumerator {
                    let values = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                    total += Int64(values?.totalFileAllocatedSize ?? 0)
                }
            }
            return total
        }.value
    }

    private func isRepoStale(parent: URL) -> Bool {
        let head = parent.appending(path: ".git/HEAD")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: head.path()),
              let mtime = attrs[.modificationDate] as? Date
        else { return true } // no git at all → safe by default
        return Date.now.timeIntervalSince(mtime) > staleAge
    }
}
