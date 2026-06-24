import Foundation

/// `/redfish/v1/Systems/<id>/Storage/<id>` — a storage subsystem (controller + drives).
struct StorageSubsystem: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var status: RedfishStatus?
    var drives: [ODataRef]?
    var storageControllers: [StorageController]?
    var volumes: ODataRef?

    var id: String { odataID ?? idField ?? "unidentified" }

    struct StorageController: Codable {
        var name: String?
        var model: String?
        var manufacturer: String?
        var firmwareVersion: String?
        var speedGbps: Double?
        var supportedRAIDTypes: [String]?
        var supportedDeviceProtocols: [String]?
        var cacheSummary: CacheSummary?
        var status: RedfishStatus?

        struct CacheSummary: Codable {
            var totalCacheSizeMiB: Double?
            enum CodingKeys: String, CodingKey { case totalCacheSizeMiB = "TotalCacheSizeMiB" }
        }

        /// Whether this controller is a real RAID controller (PERC) vs a plain HBA.
        var isRAIDCapable: Bool { !(supportedRAIDTypes ?? []).isEmpty }

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case model = "Model"
            case manufacturer = "Manufacturer"
            case firmwareVersion = "FirmwareVersion"
            case speedGbps = "SpeedGbps"
            case supportedRAIDTypes = "SupportedRAIDTypes"
            case supportedDeviceProtocols = "SupportedDeviceProtocols"
            case cacheSummary = "CacheSummary"
            case status = "Status"
        }
    }

    /// The RAID controller (if any) backing this subsystem.
    var raidController: StorageController? {
        storageControllers?.first { $0.isRAIDCapable } ?? storageControllers?.first
    }

    /// Whether this subsystem is a real RAID controller (PERC) we can configure — robust to
    /// firmware that leaves `SupportedRAIDTypes` empty. Excludes plain AHCI/SATA controllers.
    var isRAID: Bool {
        if (idField ?? "").uppercased().hasPrefix("RAID") { return true }
        guard let c = storageControllers?.first else { return false }
        if c.isRAIDCapable { return true }
        let m = (c.model ?? c.name ?? "").uppercased()
        if m.contains("PERC") || m.contains("RAID") || m.contains("BOSS") { return true }
        if (c.cacheSummary?.totalCacheSizeMiB ?? 0) > 0 { return true }
        return false
    }

    /// Path to the Volumes collection for creating virtual disks.
    var volumesPath: String? { volumes?.odataID ?? odataID.map { $0 + "/Volumes" } }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case status = "Status"
        case drives = "Drives"
        case storageControllers = "StorageControllers"
        case volumes = "Volumes"
    }
}

/// `/redfish/v1/Systems/<id>/Storage/<id>/Volumes/<id>` — a RAID virtual disk.
struct Volume: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var displayName: String?
    var raidType: String?
    var volumeType: String?
    var capacityBytes: Double?
    var encrypted: Bool?
    var status: RedfishStatus?
    var links: Links?

    var id: String { odataID ?? idField ?? "volume" }
    var driveCount: Int { links?.drives?.count ?? 0 }
    var title: String { name ?? displayName ?? idField ?? "Virtual Disk" }

    /// True for a real RAID virtual disk; false for a Non-RAID passthrough / raw device
    /// (a bare physical disk the controller exposes directly).
    var isVirtualDisk: Bool {
        (volumeType ?? "").caseInsensitiveCompare("RawDevice") != .orderedSame
            && (raidType ?? "None") != "None"
    }
    var raidLabel: String { isVirtualDisk ? (raidType ?? "RAID") : "Non-RAID" }

    struct Links: Codable {
        var drives: [ODataRef]?
        enum CodingKeys: String, CodingKey { case drives = "Drives" }
    }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case displayName = "DisplayName"
        case raidType = "RAIDType"
        case volumeType = "VolumeType"
        case capacityBytes = "CapacityBytes"
        case encrypted = "Encrypted"
        case status = "Status"
        case links = "Links"
    }
}

/// `/redfish/v1/Systems/<id>/Storage/<id>/Drives/<id>` — a physical drive.
struct Drive: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var model: String?
    var manufacturer: String?
    var serialNumber: String?
    var revision: String?
    var mediaType: String?
    var `protocol`: String?
    var capacityBytes: Double?
    var blockSizeBytes: Double?
    var rotationSpeedRPM: Double?
    var capableSpeedGbs: Double?
    var negotiatedSpeedGbs: Double?
    var failurePredicted: Bool?
    var predictedMediaLifeLeftPercent: Double?
    var status: RedfishStatus?

    var id: String { odataID ?? idField ?? "unidentified" }
    var isSSD: Bool { (mediaType ?? "").uppercased() == "SSD" }
    /// Dell FQDD (e.g. "Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1"), used as the
    /// target identifier for RAID actions like BlinkTarget.
    var fqdd: String? { idField }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case model = "Model"
        case manufacturer = "Manufacturer"
        case serialNumber = "SerialNumber"
        case revision = "Revision"
        case mediaType = "MediaType"
        case `protocol` = "Protocol"
        case capacityBytes = "CapacityBytes"
        case blockSizeBytes = "BlockSizeBytes"
        case rotationSpeedRPM = "RotationSpeedRPM"
        case capableSpeedGbs = "CapableSpeedGbs"
        case negotiatedSpeedGbs = "NegotiatedSpeedGbs"
        case failurePredicted = "FailurePredicted"
        case predictedMediaLifeLeftPercent = "PredictedMediaLifeLeftPercent"
        case status = "Status"
    }
}
