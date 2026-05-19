import Foundation

/// A single cleanable thing — file, directory, cache bucket, leftover.
///
/// Value type, `Sendable`, identity is the URL hash so identical paths
/// dedup across scanners.
struct ScanItem: Hashable, Identifiable, Sendable {
    let url: URL
    let size: Int64
    let modified: Date
    let kind: Kind
    let recoverable: Bool
    let confidence: Confidence

    var id: URL { url }

    enum Kind: Hashable, Sendable {
        case cache
        case log
        case devArtifact(toolchain: String)   // "node", "rust", "swift", …
        case appLeftover(bundleID: String)
        case largeFile
        case duplicate(groupID: UUID)
        case backup
        case browserData(browser: String)
    }

    /// How sure we are this is safe to remove without breaking anything.
    /// "review" means we won't ship it in Smart Clean — only Modules.
    enum Confidence: Sendable {
        case safe
        case review
        case risky
    }
}
