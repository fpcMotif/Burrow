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
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                reclaimed += size
            }
            do {
                var dst: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &dst)
            } catch {
                errors[path] = error.localizedDescription
            }
        }
        reply(reclaimed, errors)
    }

    func runMaintenance(tasks: [String], reply: @escaping (Bool, String?) -> Void) {
        // Stub. Real impl execs /usr/sbin/periodic, dscacheutil, etc.
        reply(true, nil)
    }

    func version(reply: @escaping (String) -> Void) {
        reply(Self.version)
    }
}

let delegate = HelperService()
let listener = NSXPCListener(machServiceName: "dev.burrow.Helper")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
