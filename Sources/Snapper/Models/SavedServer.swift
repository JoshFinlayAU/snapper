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

    /// Bare host/IP without scheme or path, e.g. "10.0.0.5".
    var bareHost: String {
        host
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/").first.map(String.init) ?? host
    }

    /// Display address, e.g. "10.0.0.5:443".
    var displayAddress: String {
        if let port { return "\(bareHost):\(port)" }
        return bareHost
    }

    /// The iDRAC web UI / HTML5 virtual-console base URL.
    var webConsoleURL: URL? {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = bareHost
        if let port { comps.port = port }
        return comps.url
    }

    /// A `vnc://host:port` URL handed off to macOS Screen Sharing.
    func vncURL(port: Int) -> URL? {
        URL(string: "vnc://\(bareHost):\(port)")
    }
}
