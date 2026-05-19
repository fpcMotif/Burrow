import AppKit
import Foundation

/// Thin wrapper around `NSWorkspace.recycle` that returns when *all*
/// items have been moved to Trash (or failed). Reversible by design.
enum Trash {
    @discardableResult
    static func send(_ urls: [URL]) async -> [URL: any Error] {
        await withCheckedContinuation { continuation in
            var failures: [URL: any Error] = [:]
            let group = DispatchGroup()
            for url in urls {
                group.enter()
                NSWorkspace.shared.recycle([url]) { _, error in
                    if let error { failures[url] = error }
                    group.leave()
                }
            }
            group.notify(queue: .global()) {
                continuation.resume(returning: failures)
            }
        }
    }
}
