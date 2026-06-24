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
        var status: RedfishStatus?
        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case model = "Model"
            case manufacturer = "Manufacturer"
            case firmwareVersion = "FirmwareVersion"
            case speedGbps = "SpeedGbps"
            case status = "Status"
        }
    }

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
