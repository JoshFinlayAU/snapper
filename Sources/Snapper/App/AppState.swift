import Foundation
import Combine
import SwiftUI

/// Top-level application state: the saved-server store plus the set of open connection tabs.
@MainActor
final class AppState: ObservableObject {
    @Published var store = ServerStore()
    @Published var connections: [ServerConnection] = []
    @Published var selectedConnectionID: UUID?
    @Published var sidebarSelection: SidebarItem? = .servers

    enum SidebarItem: Hashable {
        case servers
    }

    /// Open (or focus) a tab for the given saved server and start connecting.
    func openConnection(for server: SavedServer) {
        if let existing = connections.first(where: { $0.id == server.id }) {
            selectedConnectionID = existing.id
            return
        }
        guard let password = store.password(for: server) else {
            // No stored password — surface a transient failed tab so the user gets feedback.
            let conn = ServerConnection(server: server, password: "")
            conn.phase = .failed("No saved password. Edit the server to set credentials.")
            connections.append(conn)
            selectedConnectionID = conn.id
            return
        }
        let conn = ServerConnection(server: server, password: password)
        connections.append(conn)
        selectedConnectionID = conn.id
        Task { await conn.connect() }
    }

    func closeConnection(_ conn: ServerConnection) {
        conn.disconnect()
        connections.removeAll { $0.id == conn.id }
        if selectedConnectionID == conn.id {
            selectedConnectionID = connections.last?.id
        }
    }

    func reconnect(_ conn: ServerConnection) {
        conn.disconnect()
        Task { await conn.connect() }
    }

    var selectedConnection: ServerConnection? {
        connections.first { $0.id == selectedConnectionID }
    }
}
