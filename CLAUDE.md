# Burrow

Native macOS disk cleaner. SwiftUI 6, Swift 6 strict concurrency, zero
telemetry, pay-once. See `DESIGN.md` for architecture and `Docs/COMPARISON.md`
for the case against CleanMyMac / Mole.

## Build

Dev environment is declared in `flake.nix` (xcodegen, swiftlint, gh pinned via `flake.lock`). Xcode itself comes from Apple — Nix can't ship SwiftUI 6 / Swift 6 toolchains.

```sh
nix develop                        # or `direnv allow` once, then auto-loads
xcodegen generate                  # consumes project.yml at repo root
open Burrow.xcodeproj
```

Fallback without Nix: `brew install xcodegen swiftlint gh`.

## Agent skills

### Issue tracker

GitHub Issues at `github.com/fpcMotif/Burrow` via the `gh` CLI. See `Docs/agents/issue-tracker.md`.

### Triage labels

Canonical names (no remapping). See `Docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `Docs/adr/` at the repo root (created lazily by `/grill-with-docs`). See `Docs/agents/domain.md`.
