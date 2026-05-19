import Foundation
import SwiftData

/// SwiftData-persisted record of a cleanup. Kept for 30 days so the user
/// can audit and (when items still live in Trash) restore an entire run.
@Model
final class CleanRecord {
    var id: UUID
    var performedAt: Date
    var bytesReclaimed: Int64
    var paths: [String]
    var scannerID: String
    var trashed: Bool

    init(
        id: UUID = UUID(),
        performedAt: Date = .now,
        bytesReclaimed: Int64,
        paths: [String],
        scannerID: String,
        trashed: Bool
    ) {
        self.id = id
        self.performedAt = performedAt
        self.bytesReclaimed = bytesReclaimed
        self.paths = paths
        self.scannerID = scannerID
        self.trashed = trashed
    }
}

/// User-defined "never touch" rules — globs that exclude paths from every
/// scanner. Persisted so the user only types `~/Projects/sacred` once.
@Model
final class IgnoreRule {
    var glob: String
    var createdAt: Date

    init(glob: String, createdAt: Date = .now) {
        self.glob = glob
        self.createdAt = createdAt
    }
}
