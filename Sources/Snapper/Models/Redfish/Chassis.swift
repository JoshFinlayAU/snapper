import Foundation

/// `/redfish/v1/Chassis/<id>` — a physical chassis enclosure.
struct Chassis: Codable, Identifiable {
    let odataID: String?
    var id: String { odataID ?? idField ?? "unidentified" }

    var idField: String?
    var name: String?
    var chassisType: String?
    var manufacturer: String?
    var model: String?
    var serialNumber: String?
    var partNumber: String?
    var assetTag: String?
    var skuField: String?
    var powerState: String?
    var status: RedfishStatus?

    var thermal: ODataRef?
    var power: ODataRef?
    var thermalSubsystem: ODataRef?
    var powerSubsystem: ODataRef?
    var location: Location?

    struct Location: Codable {
        var placement: Placement?
        struct Placement: Codable {
            var rack: String?
            var row: String?
            enum CodingKeys: String, CodingKey {
                case rack = "Rack"
                case row = "Row"
            }
        }
        enum CodingKeys: String, CodingKey {
            case placement = "Placement"
        }
    }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case chassisType = "ChassisType"
        case manufacturer = "Manufacturer"
        case model = "Model"
        case serialNumber = "SerialNumber"
        case partNumber = "PartNumber"
        case assetTag = "AssetTag"
        case skuField = "SKU"
        case powerState = "PowerState"
        case status = "Status"
        case thermal = "Thermal"
        case power = "Power"
        case thermalSubsystem = "ThermalSubsystem"
        case powerSubsystem = "PowerSubsystem"
        case location = "Location"
    }
}
