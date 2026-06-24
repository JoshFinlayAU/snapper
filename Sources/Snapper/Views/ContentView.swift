import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEditor = false
    @State private var editingServer: SavedServer?

    var body: some View {
        NavigationSplitView {
            ServerSidebar(
                onAdd: { presentEditor(nil) },
                onEdit: { presentEditor($0) }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            MainArea()
        }
        .sheet(isPresented: $showingEditor) {
            ServerEditorView(server: editingServer)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addServerRequested)) { _ in
            presentEditor(nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshRequested)) { _ in
            if let conn = appState.selectedConnection {
                Task { await conn.refresh() }
            }
        }
    }

    private func presentEditor(_ server: SavedServer?) {
        editingServer = server
        showingEditor = true
    }
}

/// The right-hand area: a tab strip of open connections plus the active connection view,
/// or an empty-state prompt when nothing is connected.
struct MainArea: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !appState.connections.isEmpty {
                ConnectionTabBar()
                Divider()
            }
            if let conn = appState.selectedConnection {
                ConnectionView(connection: conn)
                    .id(conn.id)
            } else {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBackground)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 64))
                .foregroundStyle(Theme.headerGradient)
            Text("No server connected")
                .font(.title2.weight(.semibold))
            Text("Select a server from the sidebar to connect, or press ⌘N to add one.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
