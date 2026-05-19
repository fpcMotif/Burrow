import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppModel.Route?
    @Environment(AppModel.self) private var model

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Dashboard", systemImage: "square.grid.2x2")
                    .tag(AppModel.Route.dashboard)
                Label("Smart Clean", systemImage: "sparkles")
                    .tag(AppModel.Route.smartClean)
                Label("Disk Map", systemImage: "rectangle.split.3x3")
                    .tag(AppModel.Route.diskMap)
            }
            Section("Modules") {
                ForEach(Scanners.all, id: \.id) { scanner in
                    moduleRow(scanner)
                        .tag(AppModel.Route.module(scanner.id))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Burrow")
        .toolbar {
            ToolbarItem {
                if model.isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await model.rescanAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Rescan everything")
                }
            }
        }
    }

    private func moduleRow(_ scanner: any Scanning) -> some View {
        let items = model.findings[scanner.id] ?? []
        let bytes = items.reduce(Int64(0)) { $0 + $1.size }
        return HStack {
            Label(scanner.category.title, systemImage: scanner.category.symbol)
                .foregroundStyle(scanner.category.tint)
            Spacer()
            if bytes > 0 {
                Text(ByteFormatter.string(bytes))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
