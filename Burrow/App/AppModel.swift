import Foundation
import Observation

/// Root view-model. One per window-group lifecycle.
///
/// `@Observable` (Swift 5.9+) replaces `ObservableObject`; SwiftUI tracks
/// only the properties actually read in each view, so coarse updates here
/// are fine.
@MainActor @Observable
final class AppModel {
    enum Route: Hashable, Sendable {
        case dashboard
        case smartClean
        case module(ScannerID)
        case diskMap
    }

    var route: Route = .dashboard
    var isScanning: Bool = false

    /// Latest scan items per scanner, keyed by id. Replaced atomically when
    /// a scanner finishes so the UI never sees a torn intermediate state.
    var findings: [ScannerID: [ScanItem]] = [:]

    /// Total reclaimable bytes across every finished scanner.
    var reclaimable: Int64 {
        findings.values.reduce(0) { acc, items in
            acc + items.reduce(0) { $0 + $1.size }
        }
    }

    private let engine = ScanEngine()

    func rescanAll() async {
        isScanning = true
        defer { isScanning = false }
        for await event in await engine.run(scanners: Scanners.all) {
            apply(event)
        }
    }

    func startSmartClean() async {
        isScanning = true
        route = .smartClean
        defer { isScanning = false }
        for await event in await engine.run(scanners: Scanners.smartClean) {
            apply(event)
        }
    }

    private func apply(_ event: ScanEvent) {
        switch event {
        case .started:
            break
        case .progress(let id, let items):
            findings[id, default: []].append(contentsOf: items)
        case .finished(let id, let items):
            findings[id] = items
        case .failed(let id, let error):
            findings[id] = []
            // TODO: surface in UI banner
            _ = error
        }
    }
}
