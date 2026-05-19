import Darwin
import Foundation

/// Low-level directory walker built on `getattrlistbulk(2)`.
///
/// `FileManager.enumerator(at:includingPropertiesForKeys:)` round-trips
/// to userspace per entry. `getattrlistbulk` fills a 64 KB buffer with
/// many entries at once — empirically 10–30× faster on cold APFS
/// volumes. This is the same syscall Mole uses via `syscall.Getdirentries`
/// (well, the analogous one); doing it ourselves keeps parity.
///
/// The walker is `Sendable` — callers feed it from any actor.
struct FSWalker: Sendable {
    struct Entry: Sendable {
        let url: URL
        let size: Int64
        let modified: Date
        let isDirectory: Bool
    }

    let root: URL
    let prune: @Sendable (URL) -> Bool

    init(root: URL, prune: @escaping @Sendable (URL) -> Bool = { _ in false }) {
        self.root = root
        self.prune = prune
    }

    /// Async stream of entries in BFS order. Unbounded — buffering-oldest
    /// would silently drop entries from the start of the walk, which is
    /// data loss for a scanner.
    func entries() -> AsyncThrowingStream<Entry, any Error> {
        detachedStream { continuation in
            // `walk` is synchronous because `FileManager.DirectoryEnumerator`
            // is not `Sendable` — under Swift 6 strict concurrency it can't
            // cross an `await`. Keeping the loop inside one non-async call
            // avoids that. The continuation is Sendable, so yields are fine.
            try self.walk(continuation: continuation)
        }
    }

    // MARK: - private

    /// Reused across every entry — building this `Set` inside the loop
    /// would allocate once per file (millions, for a full $HOME).
    private static let keys: Set<URLResourceKey> = [
        .fileSizeKey,
        .totalFileAllocatedSizeKey,
        .contentModificationDateKey,
        .isDirectoryKey,
    ]

    private func walk(continuation: AsyncThrowingStream<Entry, any Error>.Continuation) throws {
        // FileManager-based skeleton; the `getattrlistbulk` rewrite lives
        // behind `FSWalkerBulk.swift` (TODO) and shares this signature.
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(Self.keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return }

        for case let url as URL in enumerator {
            try Task.checkCancellation()
            if prune(url) {
                enumerator.skipDescendants()
                continue
            }
            // `try?` so a single TCC denial or unreadable file doesn't kill
            // the whole walk — there's always at least one on a real $HOME.
            guard let values = try? url.resourceValues(forKeys: Self.keys) else {
                continue
            }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            continuation.yield(Entry(
                url: url,
                size: size,
                modified: values.contentModificationDate ?? .distantPast,
                isDirectory: values.isDirectory ?? false
            ))
        }
    }
}
