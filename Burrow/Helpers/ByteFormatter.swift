import Foundation

enum ByteFormatter {
    /// Matches Finder's display (decimal units, e.g. "1.2 MB"). The
    /// `.byteCount` format style is a `Sendable` value type — unlike
    /// `ByteCountFormatter`, which would need a `@MainActor` shared
    /// instance to satisfy Swift 6 strict concurrency.
    static func string(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }
}
