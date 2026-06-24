import SwiftUI

/// The view for a single connected server: a section picker plus the section content.
struct ConnectionView: View {
    @ObservedObject var connection: ServerConnection
    @EnvironmentObject var appState: AppState
    @State private var section: Section = .dashboard

    enum Section: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case thermal = "Thermal"
        case power = "Power"
        case storage = "Storage"
        case inventory = "Inventory"
        case logs = "Logs"
        case idrac = "iDRAC"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2.fill"
            case .thermal: return "thermometer.medium"
            case .power: return "bolt.fill"
            case .storage: return "internaldrive.fill"
            case .inventory: return "shippingbox.fill"
            case .logs: return "list.bullet.rectangle.fill"
            case .idrac: return "wrench.and.screwdriver.fill"
            }
        }
    }

    private var sections: [Section] {
        var all = Section.allCases
        if connection.snapshot?.isDell != true {
            all.removeAll { $0 == .idrac }
        }
        return all
    }

    var body: some View {
        switch connection.phase {
        case .connecting, .idle:
            ConnectingView(connection: connection)
        case .failed(let message):
            ConnectionErrorView(message: message) {
                appState.reconnect(connection)
            }
        case .connected:
            connectedBody
        }
    }

    private var connectedBody: some View {
        VStack(spacing: 0) {
            ConnectionToolbar(connection: connection, section: $section, sections: sections)
            Divider()
            ScrollView {
                content
                    .padding(20)
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let snapshot = connection.snapshot {
            switch section {
            case .dashboard: DashboardView(connection: connection, snapshot: snapshot)
            case .thermal: ThermalView(snapshot: snapshot, history: connection.history)
            case .power: PowerView(connection: connection, snapshot: snapshot)
            case .storage: StorageView(snapshot: snapshot)
            case .inventory: InventoryView(snapshot: snapshot)
            case .logs: LogsView(logs: connection.logs)
            case .idrac: DellView(snapshot: snapshot)
            }
        } else {
            ProgressView("Loading…")
        }
    }
}

private struct ConnectionToolbar: View {
    @ObservedObject var connection: ServerConnection
    @Binding var section: ConnectionView.Section
    let sections: [ConnectionView.Section]

    var body: some View {
        HStack(spacing: 12) {
            Picker("", selection: $section) {
                ForEach(sections) { s in
                    Label(s.rawValue, systemImage: s.icon).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            if connection.isRefreshing {
                ProgressView().controlSize(.small)
            }
            if let snap = connection.snapshot {
                Text("Updated \(snap.capturedAt, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: Binding(
                get: { connection.autoRefresh },
                set: { connection.setAutoRefresh($0) }
            )) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .toggleStyle(.button)
            .help("Auto-refresh every \(Int(connection.refreshInterval))s")

            Button {
                Task { await connection.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh now (⌘R)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct ConnectingView: View {
    @ObservedObject var connection: ServerConnection
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("Connecting to \(connection.server.displayAddress)…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ConnectionErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            Text("Connection failed")
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
