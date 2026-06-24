import Foundation

/// `/redfish/v1/Managers/<id>` — a BMC (e.g. iDRAC).
struct Manager: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var managerType: String?
    var model: String?
    var firmwareVersion: String?
    var dateTime: String?
    var uuid: String?
    var powerState: String?
    var status: RedfishStatus?
    var logServices: ODataRef?
    var ethernetInterfaces: ODataRef?

    var id: String { odataID ?? idField ?? "unidentified" }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case managerType = "ManagerType"
        case model = "Model"
        case firmwareVersion = "FirmwareVersion"
        case dateTime = "DateTime"
        case uuid = "UUID"
        case powerState = "PowerState"
        case status = "Status"
        case logServices = "LogServices"
        case ethernetInterfaces = "EthernetInterfaces"
    }
}

/// A log service such as the System Event Log (SEL) or Lifecycle Controller log.
struct LogService: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var entries: ODataRef?

    var id: String { odataID ?? idField ?? "unidentified" }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case entries = "Entries"
    }
}

/// An individual log entry.
struct LogEntry: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var message: String?
    var messageID: String?
    var severity: String?
    var created: String?
    var entryType: String?
    var sensorType: String?

    var id: String { odataID ?? idField ?? "unidentified" }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case message = "Message"
        case messageID = "MessageId"
        case severity = "Severity"
        case created = "Created"
        case entryType = "EntryType"
        case sensorType = "SensorType"
    }

    var health: RedfishHealth {
        switch (severity ?? "").uppercased() {
        case "OK": return .ok
        case "WARNING": return .warning
        case "CRITICAL": return .critical
        default: return .unknown
        }
    }
}
