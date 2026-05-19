import Charts
import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                breakdown
                actions
            }
            .padding(32)
        }
        .background(backdrop)
        .navigationTitle("Dashboard")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reclaimable")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(ByteFormatter.string(model.reclaimable))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: model.reclaimable)
            if model.isScanning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var breakdown: some View {
        Chart {
            ForEach(slices) { slice in
                SectorMark(
                    angle: .value("Size", slice.bytes),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(slice.category.tint)
                .annotation(position: .overlay) {
                    if slice.bytes > model.reclaimable / 20 {
                        Text(slice.category.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(height: 240)
    }

    private var actions: some View {
        // The `⇧⌘K` shortcut lives on the menu command (BurrowApp); this
        // button reuses the same action without re-binding the shortcut.
        HStack(spacing: 12) {
            Button {
                Task { await model.startSmartClean() }
            } label: {
                Label("Smart Clean", systemImage: "sparkles")
                    .frame(minWidth: 140)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Button {
                Task { await model.rescanAll() }
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .controlSize(.large)
        }
    }

    private var backdrop: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                .init(0, 1), .init(0.5, 1), .init(1, 1),
            ],
            colors: [
                .blue.opacity(0.10), .purple.opacity(0.08), .pink.opacity(0.06),
                .indigo.opacity(0.06), .clear, .teal.opacity(0.06),
                .clear, .clear, .clear,
            ]
        )
        .ignoresSafeArea()
    }

    // MARK: - slices

    private struct Slice: Identifiable {
        let id: ScannerID
        let category: ScanCategory
        let bytes: Int64
    }

    private var slices: [Slice] {
        Scanners.all.compactMap { scanner -> Slice? in
            let bytes = model.bytesByScanner[scanner.id] ?? 0
            guard bytes > 0 else { return nil }
            return Slice(id: scanner.id, category: scanner.category, bytes: bytes)
        }
        .sorted { $0.bytes > $1.bytes }
    }
}
