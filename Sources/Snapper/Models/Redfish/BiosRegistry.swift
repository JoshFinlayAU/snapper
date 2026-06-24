import Foundation

/// `/redfish/v1/Systems/<id>/Bios/BiosRegistry` — the attribute registry describing every
/// BIOS setting's type, allowed values, bounds and read-only state. Drives typed editing.
struct BiosRegistry: Decodable {
    var registryEntries: RegistryEntries?

    struct RegistryEntries: Decodable {
        var attributes: [BiosAttributeDef]
        var menus: [BiosMenu]

        enum CodingKeys: String, CodingKey {
            case attributes = "Attributes"
            case menus = "Menus"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Decode lossily: a single malformed attribute entry must not discard the whole
            // registry (iDRAC ships hundreds of entries with varied field types).
            let wrapped = try container.decodeIfPresent([Failable<BiosAttributeDef>].self, forKey: .attributes)
            attributes = (wrapped ?? []).compactMap { $0.value }
            let menuWrapped = try container.decodeIfPresent([Failable<BiosMenu>].self, forKey: .menus)
            menus = (menuWrapped ?? []).compactMap { $0.value }
        }
    }

    enum CodingKeys: String, CodingKey { case registryEntries = "RegistryEntries" }

    /// Flatten the entries into a name → definition map.
    var byName: [String: BiosAttributeDef] {
        var map: [String: BiosAttributeDef] = [:]
        for def in registryEntries?.attributes ?? [] {
            if let name = def.attributeName { map[name] = def }
        }
        return map
    }

    /// Map a menu reference (an attribute's `MenuPath`) to its human display name.
    var menuDisplayNames: [String: String] {
        var map: [String: String] = [:]
        for menu in registryEntries?.menus ?? [] {
            guard let display = menu.displayName?.trimmingCharacters(in: .whitespaces), !display.isEmpty else { continue }
            if let path = menu.menuPath { map[path] = display }
            if let name = menu.menuName { map[name] = display }
        }
        return map
    }
}

/// A BIOS settings menu/category from the registry (e.g. "Boot Settings").
struct BiosMenu: Decodable {
    var menuName: String?
    var displayName: String?
    var menuPath: String?
    var displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case menuName = "MenuName"
        case displayName = "DisplayName"
        case menuPath = "MenuPath"
        case displayOrder = "DisplayOrder"
    }
}

/// Turns a raw BIOS `MenuPath` reference into a readable category name when the registry's
/// Menus don't provide an explicit display name — e.g. "./BootSettingsRef" → "Boot Settings".
enum BiosMenuName {
    private static let substitutions: [String: String] = [
        "Mem": "Memory", "Proc": "Processor", "Bios": "BIOS", "Usb": "USB",
        "Pci": "PCI", "Pcie": "PCIe", "Nvme": "NVMe", "Sata": "SATA", "Nic": "NIC",
        "Idrac": "iDRAC", "Hdd": "HDD", "Ssd": "SSD", "Tpm": "TPM", "Uefi": "UEFI",
        "Os": "OS", "Sr": "SR", "Iov": "IOV", "Cpu": "CPU", "Io": "I/O", "Sys": "System"
    ]

    static func pretty(_ raw: String) -> String {
        // Take the last path component, drop "./" and a trailing "Ref"/"Settings…Ref".
        var token = raw.split(separator: "/").last.map(String.init) ?? raw
        token = token.replacingOccurrences(of: "./", with: "")
        if token.hasSuffix("Ref") { token = String(token.dropLast(3)) }
        guard !token.isEmpty else { return raw }

        // Split camelCase / digit boundaries into words.
        var words: [String] = []
        var current = ""
        for ch in token {
            if ch.isUppercase, !current.isEmpty, let last = current.last, !last.isUppercase {
                words.append(current); current = String(ch)
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { words.append(current) }

        let mapped = words.map { substitutions[$0] ?? $0 }
        return mapped.joined(separator: " ")
    }
}

/// Decodes `T` if possible, otherwise captures `nil` — used to skip malformed array elements
/// without failing the entire array decode.
struct Failable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? decoder.singleValueContainer().decode(T.self)
    }
}

/// One BIOS attribute's metadata from the registry.
struct BiosAttributeDef: Codable, Identifiable {
    var attributeName: String?
    var displayName: String?
    var helpText: String?
    var warningText: String?
    var type: String?            // Enumeration, String, Integer, Boolean, Password
    var readOnly: Bool?
    var hidden: Bool?
    var resetRequired: Bool?
    var menuPath: String?
    var displayOrder: Int?
    var lowerBound: Int?
    var upperBound: Int?
    var minLength: Int?
    var maxLength: Int?
    var value: [EnumValue]?      // present for Enumeration

    var id: String { attributeName ?? displayName ?? UUID().uuidString }

    struct EnumValue: Codable, Hashable {
        var valueName: String?
        var valueDisplayName: String?
        enum CodingKeys: String, CodingKey {
            case valueName = "ValueName"
            case valueDisplayName = "ValueDisplayName"
        }
    }

    enum Kind { case enumeration, integer, string, boolean, password, unknown }

    var kind: Kind {
        switch (type ?? "").lowercased() {
        case "enumeration": return .enumeration
        case "integer": return .integer
        case "string": return .string
        case "boolean": return .boolean
        case "password": return .password
        default: return .unknown
        }
    }

    var isEditable: Bool { (readOnly != true) && (kind != .unknown) }
    var label: String { displayName?.nilIfBlank ?? attributeName ?? "Attribute" }

    /// Top-level menu segment used to group attributes, e.g. both "./MemSettingsRef" and
    /// "./MemSettingsRef/PersistentMemorySettingRef" group under "MemSettingsRef".
    var group: String {
        guard let mp = menuPath?.nilIfBlank else { return "Other" }
        let stripped = mp.hasPrefix("./") ? String(mp.dropFirst(2)) : mp
        return stripped.split(separator: "/").first.map(String.init) ?? "Other"
    }

    /// Display label for an enum option's raw value.
    func optionLabel(for valueName: String) -> String {
        value?.first { $0.valueName == valueName }?.valueDisplayName?.nilIfBlank ?? valueName
    }

    /// Validate edited text against this attribute's type/bounds. Returns an error, or nil.
    func validationError(for text: String) -> String? {
        switch kind {
        case .integer:
            guard let n = Int(text) else { return "Must be a whole number" }
            if let lo = lowerBound, n < lo { return "Minimum is \(lo)" }
            if let hi = upperBound, n > hi { return "Maximum is \(hi)" }
        case .string, .password:
            if let mx = maxLength, text.count > mx { return "Max \(mx) characters" }
            if let mn = minLength, text.count < mn, !text.isEmpty { return "Min \(mn) characters" }
        case .enumeration:
            let names = (value ?? []).compactMap { $0.valueName }
            if !names.isEmpty, !names.contains(text) { return "Not an allowed value" }
        default:
            break
        }
        return nil
    }

    /// Convert edited text into the JSON-typed value to PATCH.
    func coerced(from text: String) -> Any {
        switch kind {
        case .integer: return Int(text) ?? text
        case .boolean: return (text as NSString).boolValue
        default: return text
        }
    }

    enum CodingKeys: String, CodingKey {
        case attributeName = "AttributeName"
        case displayName = "DisplayName"
        case helpText = "HelpText"
        case warningText = "WarningText"
        case type = "Type"
        case readOnly = "ReadOnly"
        case hidden = "Hidden"
        case resetRequired = "ResetRequired"
        case menuPath = "MenuPath"
        case displayOrder = "DisplayOrder"
        case lowerBound = "LowerBound"
        case upperBound = "UpperBound"
        case minLength = "MinLength"
        case maxLength = "MaxLength"
        case value = "Value"
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespaces).isEmpty ? nil : self
    }
}
