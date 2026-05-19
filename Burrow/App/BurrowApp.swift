import SwiftData
import SwiftUI
import TipKit

@main
struct BurrowApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    try? TipsBoot.configure()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(after: .newItem) {
                Button("Smart Clean") {
                    Task { await model.startSmartClean() }
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                Button("Rescan") {
                    Task { await model.rescanAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .modelContainer(for: [CleanRecord.self, IgnoreRule.self])

        Settings {
            SettingsView()
        }
    }
}
