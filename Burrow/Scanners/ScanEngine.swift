import Foundation

enum ScanEvent: Sendable {
    case started(ScannerID)
    case progress(ScannerID, [ScanItem])
    case finished(ScannerID, [ScanItem])
    case failed(ScannerID, any Error)
}

/// Orchestrates a fan-out of scanners and merges their results into a
/// single `AsyncStream`. Backpressure is handled implicitly — the engine
/// batches per scanner every 200 ms so the UI redraws at most ~5 Hz
/// during a heavy scan.
actor ScanEngine {
    private static let batchInterval: Duration = .milliseconds(200)

    func run(scanners: [any Scanning]) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for scanner in scanners {
                        group.addTask { [batchInterval = Self.batchInterval] in
                            continuation.yield(.started(scanner.id))
                            do {
                                var batch: [ScanItem] = []
                                var lastFlush = ContinuousClock.now
                                var all: [ScanItem] = []

                                for try await item in scanner.scan() {
                                    batch.append(item)
                                    all.append(item)

                                    let now = ContinuousClock.now
                                    if now - lastFlush >= batchInterval {
                                        continuation.yield(.progress(scanner.id, batch))
                                        batch.removeAll(keepingCapacity: true)
                                        lastFlush = now
                                    }
                                }
                                if !batch.isEmpty {
                                    continuation.yield(.progress(scanner.id, batch))
                                }
                                continuation.yield(.finished(scanner.id, all))
                            } catch {
                                continuation.yield(.failed(scanner.id, error))
                            }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
