import Foundation

/// Renamed from `Scanner` to dodge the collision with `Foundation.Scanner`
/// (the legacy `NSScanner` text-parser). Reads naturally at conformance:
/// `struct DevJunkScanner: Scanning`.
protocol Scanning: Sendable {
    var id: ScannerID { get }
    var category: ScanCategory { get }

    /// Emits items as they are discovered. The engine consumes this once
    /// per run; cancelling the consuming task cancels the scan.
    func scan() -> AsyncThrowingStream<ScanItem, any Error>
}

extension Scanning {
    /// Built-in scanners derive their id from the category. Plugins can
    /// still override to register an arbitrary string id.
    var id: ScannerID { ScannerID(category.rawValue) }
}

protocol Cleaning: Sendable {
    func clean(_ items: [ScanItem]) async throws -> CleanReport
}

struct CleanReport: Sendable {
    let removed: [URL]
    let bytesReclaimed: Int64
    let trashed: Bool
}

/// Static registry. Plugins extend this; the engine reads it.
enum Scanners {
    static let all: [any Scanning] = [
        SystemJunkScanner(),
        DevJunkScanner(),
        LargeFileScanner(threshold: 100 * 1024 * 1024),
    ]

    /// The subset run by Smart Clean — only "safe" by default.
    static let smartClean: [any Scanning] = [
        SystemJunkScanner(),
    ]

    static func scanner(for id: ScannerID) -> (any Scanning)? {
        all.first { $0.id == id }
    }
}

/// Boilerplate eliminator for the three scanners + `FSWalker` — every
/// one of them spawns a detached producer task whose cancellation must
/// chain back through `continuation.onTermination`. Centralising it
/// keeps that contract in one place.
func detachedStream<T: Sendable>(
    priority: TaskPriority = .utility,
    _ body: @escaping @Sendable (AsyncThrowingStream<T, any Error>.Continuation) async throws -> Void
) -> AsyncThrowingStream<T, any Error> {
    AsyncThrowingStream { continuation in
        let task = Task.detached(priority: priority) {
            do {
                try await body(continuation)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
