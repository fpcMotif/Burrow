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
}
