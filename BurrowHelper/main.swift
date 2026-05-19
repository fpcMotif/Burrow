import Foundation

/// Minimal XPC listener. Production version pins the connecting client by
/// code signature + team identifier before exporting any object.
final class HelperService: NSObject, BurrowHelperProtocol, NSXPCListenerDelegate {
    static let version = "0.1.0"

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection conn: NSXPCConnection
    ) -> Bool {
        // TODO: pin to signing identity once stapled.
        conn.exportedInterface = NSXPCInterface(with: BurrowHelperProtocol.self)
        conn.exportedObject = self
        conn.resume()
        return true
    }

    func recycle(paths: [String], reply: @escaping (Int64, [String: String]) -> Void) {
        var reclaimed: Int64 = 0
        var errors: [String: String] = [:]
        for path in paths {
            let url = URL(fileURLWithPath: path)
            reclaimed += Self.allocatedSize(of: url)
            do {
                var dst: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &dst)
            } catch {
                errors[path] = error.localizedDescription
            }
        }
        reply(reclaimed, errors)
    }

    /// Recursive total. `FileManager.attributesOfItem(.size)` on a
    /// directory reports the inode size (≈100 bytes), not its contents —
    /// using `URLResourceValues` walks descendants the same way scanners
    /// already do.
    private static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .totalFileAllocatedSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }
        var total: Int64 = 0
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        )
        if let enumerator {
            for case let item as URL in enumerator {
                let v = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                total += Int64(v?.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }

    func runMaintenance(tasks: [String], reply: @escaping (Bool, String?) -> Void) {
        // Stub. Real impl execs /usr/sbin/periodic, dscacheutil, etc.
        reply(true, nil)
    }

    func version(reply: @escaping (String) -> Void) {
        reply(Self.version)
    }
}

// `NSXPCListener.delegate` is `weak`, so this local binding is the only
// strong reference keeping the delegate alive for the listener's lifetime.
// Removing it lets the delegate dealloc before the first connection arrives.
let delegate = HelperService()
let listener = NSXPCListener(machServiceName: "dev.burrow.Helper")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
