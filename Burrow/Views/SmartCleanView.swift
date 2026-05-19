import SwiftUI

struct SmartCleanView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating, isActive: model.isScanning)

            Text(model.isScanning ? "Cleaning…" : "Ready")
                .font(.largeTitle.weight(.semibold))

            Text(ByteFormatter.string(model.reclaimable))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: model.reclaimable)

            Button(action: primaryAction) {
                Text(model.isScanning ? "Cancel" : "Clean Now")
                    .frame(width: 160)
            }
            .controlSize(.extraLarge)
            .buttonStyle(.borderedProminent)
            .disabled(model.reclaimable == 0 && !model.isScanning)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Smart Clean")
    }

    private func primaryAction() {
        if model.isScanning {
            model.cancelScan()
        } else {
            Task { await model.startSmartClean() }
        }
    }
}
