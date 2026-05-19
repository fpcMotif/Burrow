import QuickLook
import SwiftUI

struct ScanResultsView: View {
    let scannerID: ScannerID
    @Environment(AppModel.self) private var model
    @State private var selection = Set<ScanItem.ID>()
    @State private var previewURL: URL?
    @State private var sortOrder = [KeyPathComparator(\ScanItem.size, order: .reverse)]

    private var items: [ScanItem] {
        (model.findings[scannerID] ?? []).sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Table(items, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Path", value: \.url.path) { item in
                    Label(item.url.lastPathComponent, systemImage: icon(for: item))
                        .help(item.url.path())
                }
                TableColumn("Size", value: \.size) { item in
                    Text(ByteFormatter.string(item.size))
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 100)
                TableColumn("Modified", value: \.modified) { item in
                    Text(item.modified, style: .relative)
                        .foregroundStyle(.secondary)
                }
                .width(min: 120, ideal: 140)
                TableColumn("Safety") { item in
                    confidenceBadge(item.confidence)
                }
                .width(80)
            }
            .contextMenu(forSelectionType: ScanItem.ID.self) { ids in
                Button("Reveal in Finder") { reveal(ids) }
                Button("Quick Look") { previewURL = ids.first }
                Divider()
                Button("Move to Trash", role: .destructive) { trash(ids) }
            } primaryAction: { ids in
                previewURL = ids.first
            }
            .quickLookPreview($previewURL)
        }
        .navigationTitle(scannerID.rawValue)
        .toolbar { toolbar }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(items.count) items")
                    .font(.headline)
                Text(ByteFormatter.string(items.reduce(0) { $0 + $1.size }))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Button {
                trash(selection.isEmpty ? Set(items.map(\.id)) : selection)
            } label: {
                Label("Trash Selected", systemImage: "trash")
            }
            .disabled(items.isEmpty)
        }
    }

    private func confidenceBadge(_ c: ScanItem.Confidence) -> some View {
        let (text, color): (String, Color) = switch c {
        case .safe:   ("Safe",   .green)
        case .review: ("Review", .yellow)
        case .risky:  ("Risky",  .red)
        }
        return Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }

    private func icon(for item: ScanItem) -> String {
        switch item.kind {
        case .cache:          "shippingbox"
        case .log:            "doc.text"
        case .devArtifact:    "hammer"
        case .appLeftover:    "app"
        case .largeFile:      "doc.zipper"
        case .duplicate:      "doc.on.doc"
        case .backup:         "externaldrive"
        case .browserData:    "safari"
        }
    }

    private func reveal(_ ids: Set<ScanItem.ID>) {
        let urls = items.filter { ids.contains($0.id) }.map(\.url)
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func trash(_ ids: Set<ScanItem.ID>) {
        let urls = items.filter { ids.contains($0.id) }.map(\.url)
        Task { await Trash.send(urls) }
    }
}
