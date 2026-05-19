# Burrow vs CleanMyMac vs Mole — detail

## Engine

| | CleanMyMac | Mole | Burrow |
|---|---|---|---|
| Walker | `FTSOPEN`-style via FSEvents pre-index | `Getdirentries` | `getattrlistbulk` |
| Parallelism | thread pool, undisclosed | goroutines per root | one Swift `actor` per scanner, `TaskGroup` fan-out |
| Memory model | objc retain pools, large in-process index | Go GC, slice-heavy | streaming `AsyncSequence` → zero accumulation |
| Cancellation | none mid-scan | SIGINT only | structured cancellation via `Task.checkCancellation` |

## Privacy

CleanMyMac phones home: analytics endpoint, telemetry, license server,
malware definition pulls — at least four distinct domains. Mole is silent.
Burrow's sandbox entitlements (`Burrow.entitlements`) declare **no** network
client. Only Sparkle (signed feed) and the optional malware-rule feed (Pro,
explicit toggle) ever open a socket.

## Trust model

CleanMyMac runs an always-on launchd agent (`com.macpaw.CleanMyMacXMenu`).
Burrow ships an SMAppService daemon that is **inactive** until you click
"Approve helper" — and the daemon's only API surface is `HelperProtocol`
(see `BurrowHelper/HelperProtocol.swift`). Three methods. Audit-logged.

Mole has no privileged component; it sudos the binary directly. Cleaner in
principle but means every run reprompts, and there's no way to scope what
sudo gets you. Burrow's helper is the moral middle: privileged ops are
declared up front, the user grants them once, and the audit log is plain
text the user can `tail -f`.

## Why Swift 6 + SwiftUI 6 specifically

- **Strict concurrency** catches data races at compile time. A cleaner is
  exactly the kind of app where a misshared `[URL]` becomes a deleted
  user document. Swift 6 makes that a build error.
- **`@Observable`** drops the boilerplate of `ObservableObject`/`@Published`
  and — more importantly — lets SwiftUI invalidate views property-by-
  property. During a scan we mutate `findings` continuously; with
  `@Published` every dashboard tile redraws. With `@Observable` only the
  tiles reading the changed key redraw.
- **`AsyncSequence`** is the natural fit for streaming scan results. Mole's
  Go channels do the same job; Swift's version composes with cancellation
  and backpressure for free.
- **SwiftUI `Table` + `Charts`** are now mature enough on macOS that we
  don't need AppKit. CleanMyMac still uses `NSTableView` underneath
  custom views; we don't.
- **TipKit, MeshGradient, Symbol Effects** — pure polish, but the kind of
  polish that makes a $40/yr competitor look dated for free.

## What we deliberately don't build

- Memory-monitor menu bar widget. macOS already has Activity Monitor.
- "Speed up Mac" placebos. We measure bytes, not "performance".
- Online account / "Burrow Cloud". Local-only is the product.
- A Windows version. macOS-native means macOS-native.
