# Burrow

A native macOS cleaner. SwiftUI 6, Swift 6 strict concurrency, zero
telemetry, pay-once. Designed to feel like Apple built it and run like Mole
wrote it.

```sh
git clone https://github.com/fpcMotif/Burrow.git && cd Burrow
nix develop                  # or: direnv allow (auto-loads on cd)
xcodegen generate
open Burrow.xcodeproj
```

The dev shell pins `xcodegen`, `swiftlint`, and `gh` via `flake.nix` — Xcode itself comes from the App Store. Without Nix: `brew install xcodegen` and skip the `nix develop` step.

See [`DESIGN.md`](./DESIGN.md) for architecture, module catalog, and the
case for why this exists.

## Status

Early skeleton. The scanner actors and SwiftUI shell compile; persistence,
the helper daemon, and the disk map are stubbed.

## License

MIT.
