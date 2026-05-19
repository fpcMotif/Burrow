import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var sidebarSelection: AppModel.Route? = .dashboard

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            detailView
                .frame(minWidth: 720, minHeight: 480)
        }
        .onChange(of: sidebarSelection) { _, new in
            if let new { model.route = new }
        }
        .task(id: model.findings.count) {
            // Kick off a quick scan on first appearance if nothing yet.
            if model.findings.isEmpty && !model.isScanning {
                await model.rescanAll()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch model.route {
        case .dashboard:   DashboardView()
        case .smartClean:  SmartCleanView()
        case .diskMap:     DiskMapView()
        case .module(let id): ScanResultsView(scannerID: id)
        }
    }
}
