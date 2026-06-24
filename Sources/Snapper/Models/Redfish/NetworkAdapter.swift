import Foundation

/// `/redfish/v1/Chassis/<id>/NetworkAdapters/<id>` — physical NIC hardware (brand, model,
/// part/serial, controller firmware). Richer than the system-level EthernetInterfaces.
struct NetworkAdapter: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var manufacturer: String?
    var model: String?
    var partNumber: String?
    var serialNumber: String?
    var sku: String?
    var controllers: [Controller]?
    var status: RedfishStatus?

    var id: String { odataID ?? idField ?? "adapter" }

    struct Controller: Codable {
        var firmwarePackageVersion: String?
        enum CodingKeys: String, CodingKey {
            case firmwarePackageVersion = "FirmwarePackageVersion"
        }
    }

    var firmware: String? { controllers?.compactMap { $0.firmwarePackageVersion }.first }

    /// Best human-readable model: prefer Model, then a non-generic Name, then the slot Id.
    var displayModel: String {
        if let model, !model.isEmpty { return model }
        if let name, !name.isEmpty, !name.localizedCaseInsensitiveContains("view") { return name }
        return idField ?? "Network Adapter"
    }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case manufacturer = "Manufacturer"
        case model = "Model"
        case partNumber = "PartNumber"
        case serialNumber = "SerialNumber"
        case sku = "SKU"
        case controllers = "Controllers"
        case status = "Status"
    }
}

/// `/redfish/v1/Chassis/<id>/NetworkAdapters/<id>/NetworkPorts/<id>` — a physical port.
struct NetworkPort: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var linkStatus: String?
    var activeLinkTechnology: String?
    var physicalPortNumber: String?
    var currentLinkSpeedMbps: Double?
    var associatedNetworkAddresses: [String]?
    var supportedLinkCapabilities: [LinkCapability]?

    var id: String { odataID ?? idField ?? "port" }
    var isUp: Bool { (linkStatus ?? "").localizedCaseInsensitiveContains("up") }
    var mac: String? { associatedNetworkAddresses?.first { !$0.isEmpty } }

    /// Max advertised speed across supported link capabilities (Mbps).
    var maxSupportedMbps: Double? {
        supportedLinkCapabilities?.compactMap { $0.linkSpeedMbps }.max()
    }

    struct LinkCapability: Codable {
        var linkSpeedMbps: Double?
        var linkNetworkTechnology: String?
        enum CodingKeys: String, CodingKey {
            case linkSpeedMbps = "LinkSpeedMbps"
            case linkNetworkTechnology = "LinkNetworkTechnology"
        }
    }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case linkStatus = "LinkStatus"
        case activeLinkTechnology = "ActiveLinkTechnology"
        case physicalPortNumber = "PhysicalPortNumber"
        case currentLinkSpeedMbps = "CurrentLinkSpeedMbps"
        case associatedNetworkAddresses = "AssociatedNetworkAddresses"
        case supportedLinkCapabilities = "SupportedLinkCapabilities"
    }
}

/// `.../NetworkPorts/<id>/Oem/Dell/DellNetworkTransceivers/<id>` — the pluggable optic/DAC
/// in a port (SFP+/SFP28/QSFP), with its vendor, part, serial and media type.
struct DellNetworkTransceiver: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var vendorName: String?
    var partNumber: String?
    var serialNumber: String?
    var revision: String?
    var identifierType: String?
    var interfaceType: String?
    var deviceDescription: String?
    var fqdd: String?

    var id: String { odataID ?? fqdd ?? idField ?? "transceiver" }

    /// e.g. "SFP/SFP+/SFP28". Trimmed of empty whitespace placeholders.
    var formFactor: String? { identifierType?.trimmingCharacters(in: .whitespaces).nilIfEmpty }
    var vendor: String? { vendorName?.trimmingCharacters(in: .whitespaces).nilIfEmpty }
    var part: String? { partNumber?.trimmingCharacters(in: .whitespaces).nilIfEmpty }
    var serial: String? { serialNumber?.trimmingCharacters(in: .whitespaces).nilIfEmpty }

    /// True for fibre/optical modules, false for direct-attach copper.
    var isOptical: Bool { (interfaceType ?? "").localizedCaseInsensitiveContains("optical") }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case vendorName = "VendorName"
        case partNumber = "PartNumber"
        case serialNumber = "SerialNumber"
        case revision = "Revision"
        case identifierType = "IdentifierType"
        case interfaceType = "InterfaceType"
        case deviceDescription = "DeviceDescription"
        case fqdd = "FQDD"
    }
}

// MARK: - Composed view models (adapter → ports → transceivers)

struct NetworkAdapterDetail: Identifiable {
    let id: String
    let adapter: NetworkAdapter
    var ports: [NetworkPortDetail]
}

struct NetworkPortDetail: Identifiable {
    let id: String
    let port: NetworkPort
    var transceivers: [DellNetworkTransceiver]
    var nic: DellNIC?
}

/// `.../NetworkDeviceFunctions/<id>/Oem/Dell/DellNIC/<id>` — Dell's per-function NIC view.
/// Carries media type and pluggable-transceiver details inline (the dedicated
/// DellNetworkTransceivers collection is often empty, so this is the reliable source).
struct DellNIC: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var fqdd: String?
    var mediaType: String?
    var vendorName: String?
    var identifierType: String?
    var productName: String?
    var familyVersion: String?
    var transceiverVendorName: String?
    var transceiverPartNumber: String?
    var transceiverSerialNumber: String?

    var id: String { odataID ?? fqdd ?? idField ?? "dellnic" }

    var media: String? { mediaType?.cleanedField }
    var isCopper: Bool { (mediaType ?? "").localizedCaseInsensitiveContains("base") }
    /// A pluggable SFP/QSFP cage (may hold an optic or a direct-attach copper module).
    var isPluggable: Bool {
        let m = (mediaType ?? "").uppercased()
        return m.contains("SFF") || m.contains("SFP") || m.contains("QSFP") || m.contains("CAGE")
    }

    /// Friendly media label, e.g. "SFF_CAGE" → "SFP+", "Base T" → "Base-T".
    var mediaPretty: String? {
        guard let m = media else { return nil }
        switch m.uppercased() {
        case "SFF_CAGE", "SFP_PLUS", "SFPPLUS", "SFP+": return "SFP+"
        case "SFP28": return "SFP28"
        case let q where q.contains("QSFP"): return "QSFP"
        case let b where b.contains("BASE"): return "Base-T"
        default: return m
        }
    }
    var tVendor: String? { transceiverVendorName?.cleanedField }
    var tPart: String? { transceiverPartNumber?.cleanedField }
    var tSerial: String? { transceiverSerialNumber?.cleanedField }
    var hasTransceiver: Bool { tVendor != nil || tPart != nil || tSerial != nil }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case fqdd = "FQDD"
        case mediaType = "MediaType"
        case vendorName = "VendorName"
        case identifierType = "IdentifierType"
        case productName = "ProductName"
        case familyVersion = "FamilyVersion"
        case transceiverVendorName = "TransceiverVendorName"
        case transceiverPartNumber = "TransceiverPartNumber"
        case transceiverSerialNumber = "TransceiverSerialNumber"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension String {
    /// Trim, and treat placeholder values BMCs use for "no data" as nil.
    var cleanedField: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = ["", "null", "unknown", "not available", "n/a", "none"]
        return placeholders.contains(t.lowercased()) ? nil : t
    }
}
