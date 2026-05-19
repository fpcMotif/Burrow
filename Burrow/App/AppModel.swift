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

    /// Latest scan items per scanner, keyed by id. Single source of truth
    /// — the engine never re-buffers the full result set, only batches.
    var findings: [ScannerID: [ScanItem]] = [:]

    /// Per-scanner byte totals, kept in lock-step with `findings` so
    /// views don't need to fold the items array on every render.
    private(set) var bytesByScanner: [ScannerID: Int64] = [:]

    /// Total reclaimable bytes across every finished scanner. Maintained
    /// as the sum of `bytesByScanner` to avoid O(N) folds in views.
    private(set) var reclaimable: Int64 = 0

    /// Bumped on every `apply(_:)` so views can `.onChange` on it for
    /// expensive derived state (sorted item lists, treemap layouts).
    private(set) var findingsVersion: UInt64 = 0

    private var runningScan: Task<Void, Never>?

    func rescanAll() async {
        await run(scanners: Scanners.all)
    }

    func startSmartClean() async {
        route = .smartClean
        await run(scanners: Scanners.smartClean)
    }

    func cancelScan() {
        runningScan?.cancel()
    }

    private func run(scanners: [any Scanning]) async {
        runningScan?.cancel()
        isScanning = true
        let task = Task { @MainActor [weak self] in
            for await event in ScanEngine.run(scanners: scanners) {
                guard !Task.isCancelled else { return }
                self?.apply(event)
            }
        }
        runningScan = task
        await task.value
        isScanning = false
    }

    private func apply(_ event: ScanEvent) {
        switch event {
        case .started(let id):
            reclaimable -= bytesByScanner[id] ?? 0
            findings[id] = []
            bytesByScanner[id] = 0
        case .progress(let id, let items):
            let batchBytes = items.totalBytes
            findings[id, default: []].append(contentsOf: items)
            bytesByScanner[id, default: 0] += batchBytes
            reclaimable += batchBytes
        case .finished:
            break
        case .failed(let id, _):
            // TODO: surface in UI banner once `errors: [ScannerID: any Error]` exists.
            reclaimable -= bytesByScanner[id] ?? 0
            findings[id] = []
            bytesByScanner[id] = 0
        }
        findingsVersion &+= 1
    }
}
