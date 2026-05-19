# Burrow — Design Doc

> A privacy-first, native macOS cleaner that out-builds **CleanMyMac** on UX
> and out-runs **Mole** on capability. SwiftUI-only, Swift 6 strict
> concurrency, zero telemetry, pay-once.

---

## 1. Positioning

| | CleanMyMac X / 2025 | Mole (Go) | **Burrow** |
|---|---|---|---|
| UI | Custom Electron-feel AppKit | TUI / CLI | **Native SwiftUI 6** |
| Engine | Closed objc/Swift hybrid | Go goroutines | **Swift 6 actors + TaskGroup** |
| Telemetry | Yes (MacPaw analytics) | None | **None, sandboxed, no network** |
| License | Subscription (~$40/yr) | MIT | **MIT, pay-once for Pro modules** |
| Footprint | ~600 MB install, helper agent always running | ~10 MB single binary, no daemon | **~25 MB app, on-demand SMAppService helper** |
| Privileged ops | Always-on launchd agent | Sudo prompt per run | **SMAppService helper, signed, audit-logged** |
| Update cadence | Closed | GitHub releases | **GitHub releases + Sparkle 2** |
| Disk map | Yes | No | **TreeMap (Charts) + heatmap** |
| Dev-junk detection | Limited (Xcode-only) | Strong (node_modules, target, .venv) | **Strongest: parses lockfiles, respects .gitignore** |
| Background scan | No | No | **FSEvents-watched continuous index** |

**Thesis**: CleanMyMac wins on polish but loses on trust and weight. Mole
wins on speed and honesty but loses on UI. A native SwiftUI app with Mole's
philosophy and CleanMyMac's polish — that's the gap.

---

## 2. Tech stack (latest, as of macOS 26 / Swift 6.2)

- **Language**: Swift 6.2, strict concurrency on, complete `Sendable` enforcement
- **UI**: SwiftUI 6 — `@Observable`, `@Bindable`, `NavigationSplitView`,
  `Charts`, `MeshGradient`, `.inspector()`, `Symbol Effects`, `.scrollPosition`,
  `TipKit`, `ContainerValues`
- **Persistence**: SwiftData (scan history, ignore lists, user prefs)
- **Concurrency**: `actor` per scanner, `TaskGroup` for fan-out,
  `AsyncSequence` for streaming results to the UI
- **FS access**: `FileManager` + low-level `getattrlistbulk` for fast
  directory enumeration (10–30× faster than `enumerator(at:)` for size walks)
- **Privileged ops**: `SMAppService.daemon` + XPC; helper bundled in app, no
  installer
- **Updates**: Sparkle 2 with EdDSA signatures
- **Build**: XcodeGen (deterministic `.xcodeproj`), Tuist optional
- **Tests**: Swift Testing (`@Test`, `#expect`), snapshot tests via
  `swift-snapshot-testing`
- **CI**: GitHub Actions on `macos-15` runners, signed nightlies via fastlane

No third-party UI libs. No Electron. No Catalyst. No SwiftUI-on-AppKit hacks
beyond `NSWorkspace` for app launching and `NSSavePanel` (the official escape
hatches Apple still requires).

---

## 3. Architecture

```
┌──────────────────────────────────────────────────────┐
│  SwiftUI views (@Observable AppModel + @Bindable)    │
└──────────────┬───────────────────────────────────────┘
               │ async streams
               ▼
┌──────────────────────────────────────────────────────┐
│  ScanEngine (actor)                                  │
│  ├─ TaskGroup fan-out over [any Scanner]             │
│  └─ AsyncStream<ScanEvent> → UI                      │
└──────────────┬───────────────────────────────────────┘
               │
       ┌───────┴────────┬────────────┬──────────────┐
       ▼                ▼            ▼              ▼
 SystemJunkScanner DevJunkScanner LargeFile…   Duplicate…
  (actor)          (actor)        (actor)      (actor)
               │
               ▼
┌──────────────────────────────────────────────────────┐
│  FSWalker (low-level getattrlistbulk wrapper)        │
└──────────────┬───────────────────────────────────────┘
               │ XPC (only for sudo paths)
               ▼
┌──────────────────────────────────────────────────────┐
│  com.burrow.Helper (SMAppService daemon)             │
│  - rm -rf on /Library/Caches subpaths                │
│  - kextcache, periodic, etc.                         │
│  - audit log to ~/Library/Logs/Burrow/helper.log     │
└──────────────────────────────────────────────────────┘
```

### Why actors per scanner
- Isolates mutable state (visited inodes, dedup hash table) without locks.
- Lets `ScanEngine` cancel one scanner without killing others.
- Each scanner exposes a single `func scan() -> AsyncStream<ScanItem>` —
  the UI subscribes once and gets backpressure for free.

### Why `getattrlistbulk` over `FileManager.enumerator`
On a 1 TB SSD with 4 M files, `enumerator(at:includingPropertiesForKeys:)`
takes ~95 s. `getattrlistbulk` with a 64 KB buffer takes ~7 s. Mole gets the
same speed via Go's `syscall.Getdirentries`. We match it with a thin Swift
wrapper (`FSWalker.swift`).

---

## 4. Module catalog

Each module is a `Scanner` (conforms to the protocol below) plus a `Cleaner`
(conforms to a parallel one). They live in `Burrow/Scanners/<Name>/`.

| Module | Status | Notes |
|---|---|---|
| `SystemJunkScanner` | core | `~/Library/Caches`, `/private/var/folders/**/T`, log archives |
| `DevJunkScanner` | core | `node_modules`, `.venv`, `target/`, `.build`, `DerivedData`, Cocoapods, Carthage, `dist/`, `__pycache__`, `.next`, `.turbo`, `.cargo/registry`, `go/pkg/mod` |
| `LargeFileScanner` | core | size-ranked, Quick Look preview, age filter |
| `AppLeftoverScanner` | core | scans `~/Library/{Application Support,Preferences,Caches,Logs,Saved Application State}` for orphans |
| `DuplicateScanner` | pro | Blake3 content hashing, parallel, mmap'd, skips < 4 KB by default |
| `LoginItemsScanner` | core | SMAppService inventory + LaunchAgents/Daemons |
| `MailAttachmentScanner` | pro | Apple Mail downloads, attachments by sender |
| `iOSBackupScanner` | core | `~/Library/Application Support/MobileSync/Backup` |
| `XcodeJunkScanner` | core | DerivedData, archives, simulator runtimes, device support |
| `BrowserCacheScanner` | core | Safari, Chrome, Arc, Firefox, Brave, Orion |
| `MalwareScanner` | pro | YARA rules pulled from signed feed (no telemetry) |

---

## 5. Scanner contract

```swift
protocol Scanner: Sendable, Identifiable {
    var id: ScannerID { get }
    var category: ScanCategory { get }
    func scan() -> AsyncThrowingStream<ScanItem, any Error>
}

protocol Cleaner: Sendable {
    func clean(_ items: [ScanItem]) async throws -> CleanReport
}
```

A scanner streams `ScanItem` values; the engine batches them, dedups, and
hands them to the view layer. Cleaning is always reversible (Trash, never
`unlink` directly) unless the user explicitly opts in to "shred".

---

## 6. UX flows

### First launch
1. Splash → "Grant Full Disk Access" → opens System Settings deep link.
2. TipKit-driven 3-step tour: Dashboard, Smart Clean, Modules.
3. Background quick-scan starts immediately (caches + DerivedData).

### Smart Clean (CleanMyMac-style one-button)
- Runs `SystemJunkScanner`, `BrowserCacheScanner`, `XcodeJunkScanner`,
  `AppLeftoverScanner` in parallel.
- Presents a single recoverable total with a per-category breakdown.
- "Review" expands to the modular view; "Clean" sends to Trash.

### Disk Map (the Mole-killer)
- Treemap rendering with `Canvas` + `Path`, 60 fps even at 100k nodes.
- Click → drill in; ⌘-click → reveal in Finder.
- Heatmap toggle: color by age, by size, by type.

### Modules screen (the power-user view)
- Sidebar lists all scanners with current findings.
- Detail is a table (`Table<ScanItem>`) with sort, multi-select, Quick Look.

---

## 7. Privacy & security

- App is sandboxed. Full Disk Access granted via System Settings (TCC).
- No network calls except: (a) Sparkle update check (signed feed),
  (b) optional malware-rule feed (Pro, opt-in, signed).
- All cleanup goes through `NSWorkspace.recycle(_:completionHandler:)` so
  items land in Trash by default.
- Helper daemon is audit-logged; every privileged op writes a JSON record
  with timestamp, path, caller PID.
- Hardened runtime, notarized, stapled.

---

## 8. Performance budget

| Op | Target | How |
|---|---|---|
| Cold launch to first paint | < 250 ms | No work in `init`; defer scan to `.task` |
| Smart-Clean scan on 1 TB SSD | < 8 s | `getattrlistbulk` + parallel actors |
| Disk map render (4 M files) | < 1 s after walk | precomputed treemap layout off-main |
| UI frame time during scan | < 16 ms p99 | `AsyncStream` batched at 200 ms intervals |
| Memory peak during dup scan | < 300 MB | streaming Blake3, no `[Data]` accumulation |

---

## 9. File layout

```
Burrow/
├── DESIGN.md                  ← this doc
├── README.md
├── project.yml                ← XcodeGen
├── Burrow/
│   ├── App/
│   │   ├── BurrowApp.swift
│   │   └── AppModel.swift
│   ├── Models/
│   │   ├── ScanItem.swift
│   │   ├── ScanCategory.swift
│   │   └── CleanRecord.swift  ← @Model (SwiftData)
│   ├── Scanners/
│   │   ├── Scanner.swift
│   │   ├── ScanEngine.swift
│   │   ├── FSWalker.swift
│   │   ├── SystemJunkScanner.swift
│   │   ├── DevJunkScanner.swift
│   │   ├── LargeFileScanner.swift
│   │   └── …
│   ├── Views/
│   │   ├── RootView.swift
│   │   ├── SidebarView.swift
│   │   ├── DashboardView.swift
│   │   ├── SmartCleanView.swift
│   │   ├── ScanResultsView.swift
│   │   ├── DiskMapView.swift
│   │   └── SettingsView.swift
│   ├── Helpers/
│   │   ├── ByteFormatter.swift
│   │   ├── Trash.swift
│   │   ├── Permissions.swift
│   │   └── Tips.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Burrow.entitlements
└── BurrowHelper/
    ├── HelperProtocol.swift   ← shared with main app
    └── main.swift             ← XPC listener
```

---

## 10. Roadmap

- **v0.1** (MVP, 3 weeks): SystemJunk + DevJunk + LargeFile + Dashboard +
  Smart Clean. No helper yet; user runs unsandboxed for first beta.
- **v0.2**: SMAppService helper, AppLeftover, BrowserCache, XcodeJunk.
- **v0.3**: Disk Map, Duplicate finder (Pro).
- **v0.4**: Continuous background index via FSEvents.
- **v1.0**: Notarized, Sparkle feed, Pro license.

---

## 11. Why this beats Mole specifically

Mole is excellent at one thing — fast dev-junk discovery in Go. It's
single-binary, single-purpose, CLI. Burrow's `DevJunkScanner` matches its
speed (same syscall, parallel walks) and adds:

- **GUI you can actually browse**, with Quick Look and Reveal in Finder.
- **Lockfile awareness**: parses `package.json`, `pyproject.toml`, `Cargo.toml`
  so it knows which `node_modules` belongs to an actively-developed repo
  (last commit < 30 days) and warns before cleaning it.
- **`.gitignore` respect**: never offers to delete a `target/` directory
  that isn't in any `.gitignore` (because it may not be regeneratable).
- **Undo**: everything goes to Trash; Burrow keeps a `CleanRecord` for 30
  days so you can restore an entire cleanup as one atomic operation.

Mole users get all of the above without giving up the CLI: Burrow ships a
`burrow` CLI subtarget that talks to the same actors.
