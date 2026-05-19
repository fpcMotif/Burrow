import SwiftUI
import TipKit

struct SmartCleanTip: Tip {
    var title: Text { Text("One-click cleanup") }
    var message: Text? {
        Text("Smart Clean removes only items marked Safe. Hold ⌘⇧K from anywhere.")
    }
    var image: Image? { Image(systemName: "sparkles") }
}

struct DevJunkTip: Tip {
    var title: Text { Text("Developer junk is opt-in") }
    var message: Text? {
        Text("Burrow won't touch a build artifact whose repo was active in the last 30 days.")
    }
    var image: Image? { Image(systemName: "hammer") }
}

/// Wraps the one-shot configure call. Named to avoid shadowing
/// TipKit's `Tips` namespace.
enum TipsBoot {
    static func configure() throws {
        try Tips.configure([
            .displayFrequency(.weekly),
            .datastoreLocation(.applicationDefault),
        ])
    }
}
