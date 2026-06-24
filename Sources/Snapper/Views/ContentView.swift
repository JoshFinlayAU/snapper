import SwiftUI

/// What the editor sheet is currently doing — adding a new server or editing an existing one.
/// Driving the sheet with an Identifiable item (rather than a bool + separate state) guarantees
/// the editor always receives the correct target instead of a stale value.
enum EditorTarget: Identifiable {
    case new
    case existing(SavedServer)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let server): return server.id.uuidString
        }
    }

    var server: SavedServer? {
        switch self {
        case .new: return nil
        case .existing(let server): return server
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var editorTarget: EditorTarget?

    var body: some View {
        NavigationSplitView {
            ServerSidebar(
                onAdd: { editorTarget = .new },
                onEdit: { editorTarget = .existing($0) }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            MainArea()
        }
        .sheet(item: $editorTarget) { target in
            ServerEditorView(server: target.server)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addServerRequested)) { _ in
            editorTarget = .new
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshRequested)) { _ in
            if let conn = appState.selectedConnection {
                Task { await conn.refresh() }
            }
        }
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
            BrandLogo(size: 96)
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
