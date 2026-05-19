import SwiftUI

/// Treemap of the home directory. Squarified layout, rendered with
/// `Canvas` so it scales to 100k nodes without view-tree overhead.
///
/// This skeleton renders the top-level findings; a full implementation
/// would precompute the squarified layout off-main on every scan finish.
struct DiskMapView: View {
    @Environment(AppModel.self) private var model
    @State private var topItems: [ScanItem] = []
    @State private var hover: ScanItem?

    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
                let rects = layout(in: CGRect(origin: .zero, size: size), items: topItems)
                for (item, rect) in rects {
                    let path = Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 4)
                    ctx.fill(path, with: .color(item.kind.category.tint.opacity(0.85)))
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
        .task(id: model.findingsVersion) {
            // Recompute only when findings change — not on every render.
            topItems = model.findings.values.flatMap { $0 }
                .sorted { $0.size > $1.size }
                .prefix(50)
                .map { $0 }
        }
    }

    /// Squarified treemap (Bruls/Huijing/van Wijk). Stripped-down skeleton
    /// — slices each item proportional to its share of the remaining
    /// rectangle, flipping orientation on the longer side. Stable and
    /// readable, even if it isn't optimal aspect-ratio.
    private func layout(in rect: CGRect, items: [ScanItem]) -> [(ScanItem, CGRect)] {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        guard total > 0 else { return [] }

        var remaining = rect
        var remainingTotal = total
        var results: [(ScanItem, CGRect)] = []

        for item in items where remaining.width > 1 && remaining.height > 1 {
            let frac = CGFloat(item.size) / CGFloat(remainingTotal)
            let horizontal = remaining.width >= remaining.height
            let slice: CGRect
            if horizontal {
                let w = max(2, remaining.width * frac)
                slice = CGRect(x: remaining.minX, y: remaining.minY,
                               width: min(w, remaining.width),
                               height: remaining.height)
                remaining = CGRect(x: slice.maxX, y: remaining.minY,
                                   width: max(0, remaining.width - slice.width),
                                   height: remaining.height)
            } else {
                let h = max(2, remaining.height * frac)
                slice = CGRect(x: remaining.minX, y: remaining.minY,
                               width: remaining.width,
                               height: min(h, remaining.height))
                remaining = CGRect(x: remaining.minX, y: slice.maxY,
                                   width: remaining.width,
                                   height: max(0, remaining.height - slice.height))
            }
            results.append((item, slice))
            remainingTotal -= item.size
        }
        return results
    }
}
