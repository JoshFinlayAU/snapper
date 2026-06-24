import Foundation

/// A thin async Redfish HTTP client.
///
/// Uses HTTP Basic authentication (supported by Dell iDRAC and most BMCs) and
/// optionally trusts self-signed TLS certificates, which BMCs almost always use.
actor RedfishClient {
    let baseURL: URL
    private let username: String
    private let password: String
    private let session: URLSession

    init(host: String, port: Int?, username: String, password: String, allowSelfSigned: Bool) throws {
        var normalized = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        guard var components = URLComponents(string: normalized) else {
            throw RedfishError.invalidURL(host)
        }
        if let port { components.port = port }
        guard let url = components.url else {
            throw RedfishError.invalidURL(host)
        }
        self.baseURL = url
        self.username = username
        self.password = password

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.waitsForConnectivity = false
        let delegate = allowSelfSigned ? InsecureTLSDelegate() : nil
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    private var authHeader: String {
        let raw = "\(username):\(password)"
        let encoded = Data(raw.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }

    /// Resolve an `@odata.id` path against the service base.
    func url(for path: String) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        var comps = URLComponents()
        comps.scheme = baseURL.scheme
        comps.host = baseURL.host
        comps.port = baseURL.port
        comps.path = path
        return comps.url
    }

    private func request(path: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let url = url(for: path) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Snapper/1.0", forHTTPHeaderField: "User-Agent")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    /// Perform a GET and decode the JSON body into `T`.
    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let data = try await rawGet(path)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw RedfishError.decoding("\(path): \(error.localizedDescription)")
        }
    }

    /// Perform a GET and return the raw response data.
    func rawGet(_ path: String) async throws -> Data {
        guard let req = request(path: path) else { throw RedfishError.invalidURL(path) }
        let (data, response) = try await send(req, path: path)
        try Self.validate(response, path: path, data: data)
        return data
    }

    /// POST a JSON action (e.g. ComputerSystem.Reset).
    @discardableResult
    func postAction(_ path: String, payload: [String: Any]) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: payload)
        guard let req = request(path: path, method: "POST", body: body) else {
            throw RedfishError.invalidURL(path)
        }
        let (data, response) = try await send(req, path: path)
        try Self.validate(response, path: path, data: data)
        return data
    }

    /// PATCH a JSON resource (e.g. to change a writable property like AssetTag or Boot override).
    @discardableResult
    func patch(_ path: String, payload: [String: Any]) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: payload)
        guard let req = request(path: path, method: "PATCH", body: body) else {
            throw RedfishError.invalidURL(path)
        }
        let (data, response) = try await send(req, path: path)
        try Self.validate(response, path: path, data: data)
        return data
    }

    /// DELETE a resource (e.g. a RAID volume).
    @discardableResult
    func delete(_ path: String) async throws -> Data {
        guard let req = request(path: path, method: "DELETE") else {
            throw RedfishError.invalidURL(path)
        }
        let (data, response) = try await send(req, path: path)
        try Self.validate(response, path: path, data: data)
        return data
    }

    private func send(_ req: URLRequest, path: String) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch let err as URLError {
            throw RedfishError.transport(err.localizedDescription)
        } catch {
            throw RedfishError.transport(error.localizedDescription)
        }
    }

    private static func validate(_ response: URLResponse, path: String, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw RedfishError.unauthorized
        case 403:
            throw RedfishError.forbidden
        case 404:
            throw RedfishError.notFound(path)
        default:
            let detail = extractMessage(from: data)
            throw RedfishError.httpError(http.statusCode, detail)
        }
    }

    /// Pull a human-readable message out of a Redfish error body if present.
    private static func extractMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any] else { return nil }
        if let extended = error["@Message.ExtendedInfo"] as? [[String: Any]],
           let first = extended.first,
           let msg = first["Message"] as? String {
            return msg
        }
        return error["message"] as? String
    }
}

/// URLSession delegate that accepts self-signed server certificates.
private final class InsecureTLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
