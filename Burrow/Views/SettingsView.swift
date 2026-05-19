import SwiftData
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            IgnoreSettings()
                .tabItem { Label("Ignore", systemImage: "hand.raised") }
            AboutPane()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 360)
        .scenePadding()
    }
}

private struct GeneralSettings: View {
    @AppStorage("burrow.smartClean.includeDevJunk") private var includeDevJunk = false
    @AppStorage("burrow.largeFile.thresholdMB") private var thresholdMB: Int = 100

    var body: some View {
        Form {
            Toggle("Include developer junk in Smart Clean", isOn: $includeDevJunk)
            LabeledContent("Large-file threshold") {
                Stepper("\(thresholdMB) MB", value: $thresholdMB, in: 10...10_000, step: 10)
            }
        }
        .formStyle(.grouped)
    }
}

private struct IgnoreSettings: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \IgnoreRule.createdAt) private var rules: [IgnoreRule]
    @State private var draft = ""

    var body: some View {
        Form {
            Section("Glob patterns to never scan") {
                ForEach(rules) { rule in
                    HStack {
                        Text(rule.glob).monospaced()
                        Spacer()
                        Button(role: .destructive) {
                            ctx.delete(rule)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("~/Projects/**/sacred", text: $draft)
                    Button("Add") {
                        guard !draft.isEmpty else { return }
                        ctx.insert(IgnoreRule(glob: draft))
                        draft = ""
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Burrow").font(.title.weight(.semibold))
            Text("v0.1 — native, private, pay-once")
                .foregroundStyle(.secondary)
            Link("Source", destination: URL(string: "https://github.com/")!)
        }
        .frame(maxWidth: .infinity)
    }
}
