import Foundation

/// A server saved in the user's list. Credentials live in the Keychain, keyed by `id`.
struct SavedServer: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int?
    var username: String
    var allowSelfSigned: Bool
    var tags: [String]

    init(id: UUID = UUID(),
         name: String,
         host: String,
         port: Int? = nil,
         username: String = "root",
         allowSelfSigned: Bool = true,
         tags: [String] = []) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.allowSelfSigned = allowSelfSigned
        self.tags = tags
    }

    /// Display address, e.g. "10.0.0.5:443".
    var displayAddress: String {
        let cleaned = host
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        if let port { return "\(cleaned):\(port)" }
        return cleaned
    }
}
