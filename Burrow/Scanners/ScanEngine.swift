import Foundation

enum ScanEvent: Sendable {
    case started(ScannerID)
    case progress(ScannerID, [ScanItem])
    case finished(ScannerID)
    case failed(ScannerID, any Error)
}

/// Orchestrates a fan-out of scanners and merges their results into a
/// single `AsyncStream`. Backpressure is handled implicitly — the engine
/// batches per scanner every 200 ms so the UI redraws at most ~5 Hz
/// during a heavy scan.
///
/// `AppModel.findings` is the single source of truth: this engine never
/// re-buffers a full result set, only the in-flight batch. `.finished`
/// signals the scanner is done — the accumulated items already live in
/// the model.
enum ScanEngine {
    private static let batchInterval: Duration = .milliseconds(200)

    static func run(scanners: [any Scanning]) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for scanner in scanners {
                        group.addTask {
                            await produce(scanner: scanner, into: continuation)
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func produce(
        scanner: any Scanning,
        into continuation: AsyncStream<ScanEvent>.Continuation
    ) async {
        continuation.yield(.started(scanner.id))
        do {
            var batch: [ScanItem] = []
            var lastFlush = ContinuousClock.now

            for try await item in scanner.scan() {
                batch.append(item)
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
            continuation.yield(.finished(scanner.id))
        } catch {
            continuation.yield(.failed(scanner.id, error))
        }
    }
}
