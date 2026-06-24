import SwiftUI

/// The saved-server list in the left column.
struct ServerSidebar: View {
    @EnvironmentObject var appState: AppState
    var onAdd: () -> Void
    var onEdit: (SavedServer) -> Void

    @State private var serverPendingDelete: SavedServer?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if appState.store.servers.isEmpty {
                emptyList
            } else {
                list
            }
        }
        .frame(maxHeight: .infinity)
        .alert("Remove server?", isPresented: Binding(
            get: { serverPendingDelete != nil },
            set: { if !$0 { serverPendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { serverPendingDelete = nil }
            Button("Remove", role: .destructive) {
                if let s = serverPendingDelete {
                    if let conn = appState.connections.first(where: { $0.id == s.id }) {
                        appState.closeConnection(conn)
                    }
                    appState.store.delete(s)
                }
                serverPendingDelete = nil
            }
        } message: {
            Text("\(serverPendingDelete?.name ?? "This server") will be removed and its saved password deleted.")
        }
    }

    private var header: some View {
        HStack {
            Label("Servers", systemImage: "server.rack")
                .font(.headline)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add a server (⌘N)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyList: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No saved servers")
                .foregroundStyle(.secondary)
            Button("Add Server…", action: onAdd)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var list: some View {
        List {
            ForEach(appState.store.servers) { server in
                ServerRow(
                    server: server,
                    isConnected: appState.connections.contains { $0.id == server.id },
                    health: appState.connections.first { $0.id == server.id }?.snapshot?.overallHealth
                )
                .contentShape(Rectangle())
                .onTapGesture { appState.openConnection(for: server) }
                .contextMenu {
                    Button("Connect") { appState.openConnection(for: server) }
                    Button("Edit…") { onEdit(server) }
                    Divider()
                    Button("Remove", role: .destructive) { serverPendingDelete = server }
                }
            }
            .onMove { appState.store.move(from: $0, to: $1) }
        }
        .listStyle(.sidebar)
    }
}

private struct ServerRow: View {
    let server: SavedServer
    let isConnected: Bool
    let health: RedfishHealth?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.headerGradient.opacity(isConnected ? 1 : 0.5))
                    .frame(width: 34, height: 34)
                Image(systemName: "cpu")
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(server.displayAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let health {
                Image(systemName: health.symbol)
                    .foregroundStyle(health.color)
            } else if isConnected {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
