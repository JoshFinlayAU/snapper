import Foundation
import Combine

/// Persists the saved-server list to Application Support and credentials to the Keychain.
@MainActor
final class ServerStore: ObservableObject {
    @Published private(set) var servers: [SavedServer] = []

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Snapper", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("servers.json")
        load()
    }

    // MARK: - CRUD

    /// Add or update a server, persisting its password to the Keychain.
    func save(_ server: SavedServer, password: String?) {
        if let password, !password.isEmpty {
            KeychainService.setPassword(password, for: server.id)
        }
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
        } else {
            servers.append(server)
        }
        persist()
    }

    func delete(_ server: SavedServer) {
        servers.removeAll { $0.id == server.id }
        KeychainService.deletePassword(for: server.id)
        persist()
    }

    func password(for server: SavedServer) -> String? {
        KeychainService.password(for: server.id)
    }

    func move(from source: IndexSet, to destination: Int) {
        servers.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([SavedServer].self, from: data) {
            servers = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(servers) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
