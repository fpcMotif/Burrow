import Foundation

/// XPC contract between the sandboxed app and the privileged helper.
/// Kept intentionally narrow — the helper only does what the user has
/// approved through the GUI.
@objc(BurrowHelperProtocol)
protocol BurrowHelperProtocol {
    /// Move a list of system-owned paths to Trash. Replies with the
    /// number of bytes reclaimed and any per-path errors.
    func recycle(paths: [String], reply: @escaping (Int64, [String: String]) -> Void)

    /// Reset DNS / kextcache / periodic — maintenance tasks that
    /// strictly require root.
    func runMaintenance(tasks: [String], reply: @escaping (Bool, String?) -> Void)

    /// Helper version. Used at handshake time so the app refuses to
    /// talk to an out-of-date helper.
    func version(reply: @escaping (String) -> Void)
}
