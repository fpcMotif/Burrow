import Foundation

enum ByteFormatter {
    /// Use the system file-size formatter so the output matches Finder
    /// exactly (decimal units, "Zero KB" suppressed).
    static func string(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }

    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()
}
