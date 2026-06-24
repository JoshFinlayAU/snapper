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

    private var cancellables = Set<AnyCancellable>()

    init() {
        // `store` is a nested ObservableObject; its internal @Published changes don't
        // automatically refresh views observing AppState, so forward them explicitly.
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

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

    /// Repoint a saved server at a new host/IP (e.g. after changing the iDRAC's static IP),
    /// persist it, and reconnect the open tab to the new address.
    func updateHost(for conn: ServerConnection, to newHost: String) {
        guard var server = store.servers.first(where: { $0.id == conn.id }) else { return }
        server.host = newHost
        store.save(server, password: nil)        // password stays in the Keychain (keyed by id)
        closeConnection(conn)
        openConnection(for: server)
    }

    var selectedConnection: ServerConnection? {
        connections.first { $0.id == selectedConnectionID }
    }
}
