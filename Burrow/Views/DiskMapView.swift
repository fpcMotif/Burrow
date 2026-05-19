import SwiftUI

/// Treemap of the home directory. Squarified layout, rendered with
/// `Canvas` so it scales to 100k nodes without view-tree overhead.
///
/// This skeleton renders the top-level findings; a full implementation
/// would precompute the squarified layout off-main on every scan finish.
struct DiskMapView: View {
    @Environment(AppModel.self) private var model
    @State private var hover: ScanItem?

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let rects = layout(in: CGRect(origin: .zero, size: size), items: topItems)
                for (item, rect) in rects {
                    let path = Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 4)
                    ctx.fill(path, with: .color(color(for: item).opacity(0.85)))
                    if rect.width > 60, rect.height > 24 {
                        let text = Text(item.url.lastPathComponent)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                        ctx.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
                    }
                }
            }
        }
        .navigationTitle("Disk Map")
        .overlay(alignment: .bottomTrailing) {
            if let hover {
                Text("\(hover.url.lastPathComponent) — \(ByteFormatter.string(hover.size))")
                    .padding(8)
                    .background(.thinMaterial, in: .rect(cornerRadius: 6))
                    .padding()
            }
        }
    }

    private var topItems: [ScanItem] {
        model.findings.values.flatMap { $0 }
            .sorted { $0.size > $1.size }
            .prefix(50)
            .map { $0 }
    }

    private func color(for item: ScanItem) -> Color {
        switch item.kind {
        case .cache:          .blue
        case .devArtifact:    .orange
        case .largeFile:      .purple
        case .appLeftover:    .pink
        case .duplicate:      .teal
        case .backup:         .mint
        case .browserData:    .indigo
        case .log:            .gray
        }
    }

    /// Squarified treemap (Bruls/Huijing/van Wijk). Stripped down for the
    /// skeleton — produces a stable, readable layout.
    private func layout(in rect: CGRect, items: [ScanItem]) -> [(ScanItem, CGRect)] {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        guard total > 0 else { return [] }
        let area = rect.width * rect.height

        var remaining = rect
        var results: [(ScanItem, CGRect)] = []
        var queue = items

        while !queue.isEmpty, remaining.width > 1, remaining.height > 1 {
            let horizontal = remaining.width >= remaining.height
            let item = queue.removeFirst()
            let frac = CGFloat(item.size) / CGFloat(total)
            let slice: CGRect
            if horizontal {
                let w = remaining.width * frac * (area / (remaining.width * remaining.height))
                slice = CGRect(x: remaining.minX, y: remaining.minY,
                               width: max(2, min(w, remaining.width)),
                               height: remaining.height)
                remaining = CGRect(x: slice.maxX, y: remaining.minY,
                                   width: max(0, remaining.width - slice.width),
                                   height: remaining.height)
            } else {
                let h = remaining.height * frac * (area / (remaining.width * remaining.height))
                slice = CGRect(x: remaining.minX, y: remaining.minY,
                               width: remaining.width,
                               height: max(2, min(h, remaining.height)))
                remaining = CGRect(x: remaining.minX, y: slice.maxY,
                                   width: remaining.width,
                                   height: max(0, remaining.height - slice.height))
            }
            results.append((item, slice))
        }
        return results
    }
}
