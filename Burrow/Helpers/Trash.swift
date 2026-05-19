import AppKit
import Foundation

/// Thin wrapper around `NSWorkspace.recycle`. One batch call → one
/// Finder undo entry, fewer Mach IPC round-trips. Reversible by design.
///
/// `NSWorkspace.recycle(_:)` reports a single error per call rather than
/// per-URL; callers only need to know which URLs *didn't* land in the
/// Trash, so we return that list.
enum Trash {
    @discardableResult
    static func send(_ urls: [URL]) async -> [URL] {
        guard !urls.isEmpty else { return [] }
        do {
            let trashed = try await NSWorkspace.shared.recycle(urls)
            return urls.filter { trashed[$0] == nil }
        } catch {
            return urls
        }
    }
}
