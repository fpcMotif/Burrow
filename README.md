# Burrow

A native macOS cleaner. SwiftUI 6, Swift 6 strict concurrency, zero
telemetry, pay-once. Designed to feel like Apple built it and run like Mole
wrote it.

```
brew install xcodegen
cd Burrow
xcodegen generate
open Burrow.xcodeproj
```

See [`DESIGN.md`](./DESIGN.md) for architecture, module catalog, and the
case for why this exists.

## Status

Early skeleton. The scanner actors and SwiftUI shell compile; persistence,
the helper daemon, and the disk map are stubbed.

## License

MIT.
