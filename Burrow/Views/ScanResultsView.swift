import QuickLook
import SwiftUI

struct ScanResultsView: View {
    let scannerID: ScannerID
    @Environment(AppModel.self) private var model
    @State private var selection = Set<ScanItem.ID>()
    @State private var previewURL: URL?
    @State private var sortOrder = [KeyPathComparator(\ScanItem.size, order: .reverse)]
    @State private var sortedItems: [ScanItem] = []
    @State private var totalBytes: Int64 = 0

    private var category: ScanCategory? {
        Scanners.scanner(for: scannerID)?.category
    }

    var body: some View {
        Table(sortedItems, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Path", value: \.url.path) { item in
                Label(item.url.lastPathComponent, systemImage: item.kind.symbol)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .background(.background)
                .overlay(alignment: .bottom) { Divider() }
        }
        .navigationTitle(category?.title ?? "Results")
        .toolbar { toolbar }
        .task(id: model.findingsVersion) { resort() }
        .onChange(of: sortOrder) { _, _ in resort() }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            Text("\(sortedItems.count) items").font(.headline)
            Text(ByteFormatter.string(totalBytes))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Button {
                trash(selection.isEmpty ? Set(sortedItems.map(\.id)) : selection)
            } label: {
                Label("Trash Selected", systemImage: "trash")
            }
            .disabled(sortedItems.isEmpty)
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

    private func resort() {
        let items = model.findings[scannerID] ?? []
        sortedItems = items.sorted(using: sortOrder)
        totalBytes = items.totalBytes
    }

    private func reveal(_ ids: Set<ScanItem.ID>) {
        let urls = sortedItems.filter { ids.contains($0.id) }.map(\.url)
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func trash(_ ids: Set<ScanItem.ID>) {
        let urls = sortedItems.filter { ids.contains($0.id) }.map(\.url)
        Task { await Trash.send(urls) }
    }
}
