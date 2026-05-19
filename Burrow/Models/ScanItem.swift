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

extension ScanItem.Kind {
    /// Single source of truth for the kind→category mapping; views use
    /// this instead of maintaining a parallel switch.
    var category: ScanCategory {
        switch self {
        case .cache:       .systemJunk
        case .log:         .systemJunk
        case .devArtifact: .devJunk
        case .largeFile:   .largeFiles
        case .appLeftover: .appLeftovers
        case .duplicate:   .duplicates
        case .backup:      .backups
        case .browserData: .browserData
        }
    }

    /// SF Symbol per kind. Falls back to the category's symbol so adding
    /// a new `Kind` case doesn't require a new icon up-front.
    var symbol: String {
        switch self {
        case .cache:       "shippingbox"
        case .log:         "doc.text"
        case .devArtifact: "hammer"
        case .appLeftover: "app"
        case .largeFile:   "doc.zipper"
        case .duplicate:   "doc.on.doc"
        case .backup:      "externaldrive"
        case .browserData: "safari"
        }
    }
}

extension Sequence where Element == ScanItem {
    /// Cheap aggregate used by the dashboard, sidebar, and result views.
    var totalBytes: Int64 { reduce(0) { $0 + $1.size } }
}
