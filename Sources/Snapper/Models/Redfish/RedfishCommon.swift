import Foundation
import SwiftUI

/// A Redfish `@odata.id` reference to another resource.
struct ODataRef: Codable, Hashable {
    let odataID: String

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
    }
}

/// Health states defined by the Redfish `Status` object.
enum RedfishHealth: String, Codable, CaseIterable {
    case ok = "OK"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RedfishHealth(rawValue: raw) ?? .unknown
    }

    var color: Color {
        switch self {
        case .ok: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }

    var symbol: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var label: String { rawValue }
}

/// Resource health / state envelope used across nearly every Redfish resource.
struct RedfishStatus: Codable, Hashable {
    var state: String?
    var health: RedfishHealth?
    var healthRollup: RedfishHealth?

    enum CodingKeys: String, CodingKey {
        case state = "State"
        case health = "Health"
        case healthRollup = "HealthRollup"
    }

    /// Best available health value (rollup preferred when present).
    var effectiveHealth: RedfishHealth {
        healthRollup ?? health ?? .unknown
    }

    var isEnabled: Bool {
        guard let state else { return true }
        return state == "Enabled"
    }
}

/// A loosely-typed JSON scalar, used for free-form attribute maps (BIOS attributes,
/// iDRAC Dell attributes) whose value types vary per key and aren't known ahead of time.
enum JSONValue: Codable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        }
    }

    /// A human-editable string form of the value.
    var display: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return d == d.rounded() ? String(Int(d)) : String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return ""
        }
    }

    var boolValue: Bool {
        switch self {
        case .bool(let b): return b
        case .string(let s): return s.lowercased() == "true" || s.lowercased() == "enabled"
        case .int(let i): return i != 0
        default: return false
        }
    }

    /// Convert edited `text` back into a JSON-serializable value, preserving this value's
    /// original type where possible so PATCH payloads keep the BMC's expected types.
    func coerced(from text: String) -> Any {
        switch self {
        case .bool: return (text as NSString).boolValue
        case .int: return Int(text) ?? text
        case .double: return Double(text) ?? text
        case .string, .null: return text
        }
    }
}

/// A Redfish resource that exposes a free-form `Attributes` map — e.g. `Bios`,
/// `Bios/Settings`, and the iDRAC `Managers/{id}/Attributes` (Dell config) resource.
struct AttributeResource: Codable {
    var attributes: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case attributes = "Attributes"
    }
}

/// A member collection wrapper, e.g. `Systems`, `Chassis`.
struct RedfishCollection: Codable {
    let members: [ODataRef]
    let count: Int?

    enum CodingKeys: String, CodingKey {
        case members = "Members"
        case count = "Members@odata.count"
    }
}

/// Helpers for formatting common values.
enum Fmt {
    static func temperature(_ celsius: Double?) -> String {
        guard let c = celsius else { return "—" }
        return String(format: "%.0f°C", c)
    }

    static func watts(_ w: Double?) -> String {
        guard let w else { return "—" }
        return String(format: "%.0f W", w)
    }

    static func rpm(_ r: Double?) -> String {
        guard let r else { return "—" }
        return String(format: "%.0f RPM", r)
    }

    static func percent(_ p: Double?) -> String {
        guard let p else { return "—" }
        return String(format: "%.0f%%", p)
    }

    static func gib(_ bytes: Double?) -> String {
        guard let bytes, bytes > 0 else { return "—" }
        let gib = bytes / 1_073_741_824
        if gib >= 1024 {
            return String(format: "%.2f TiB", gib / 1024)
        }
        return String(format: "%.0f GiB", gib)
    }

    static func gibFromGiB(_ gib: Double?) -> String {
        guard let gib, gib > 0 else { return "—" }
        if gib >= 1024 {
            return String(format: "%.2f TiB", gib / 1024)
        }
        return String(format: "%.0f GiB", gib)
    }
}
