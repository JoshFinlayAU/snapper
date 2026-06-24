import Foundation

/// Errors surfaced by the Redfish client, with user-friendly messages.
enum RedfishError: LocalizedError {
    case invalidURL(String)
    case unauthorized
    case forbidden
    case notFound(String)
    case httpError(Int, String?)
    case transport(String)
    case decoding(String)
    case unsupportedAction

    var errorDescription: String? {
        switch self {
        case .invalidURL(let s):
            return "Invalid address: \(s)"
        case .unauthorized:
            return "Authentication failed — check the username and password."
        case .forbidden:
            return "Access denied — this account lacks permission for that resource."
        case .notFound(let path):
            return "Resource not found: \(path)"
        case .httpError(let code, let detail):
            if let detail, !detail.isEmpty {
                return "Server returned HTTP \(code): \(detail)"
            }
            return "Server returned HTTP \(code)."
        case .transport(let msg):
            return "Connection error: \(msg)"
        case .decoding(let msg):
            return "Could not read the server response: \(msg)"
        case .unsupportedAction:
            return "This action is not supported by the server."
        }
    }
}
