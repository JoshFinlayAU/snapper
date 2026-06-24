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
