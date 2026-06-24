import Foundation

/// `/redfish/v1/Systems/<id>/Processors/<id>`
struct Processor: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var manufacturer: String?
    var model: String?
    var processorType: String?
    var processorArchitecture: String?
    var instructionSet: String?
    var maxSpeedMHz: Double?
    var totalCores: Int?
    var totalThreads: Int?
    var socket: String?
    var status: RedfishStatus?

    var id: String { odataID ?? idField ?? "unidentified" }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case manufacturer = "Manufacturer"
        case model = "Model"
        case processorType = "ProcessorType"
        case processorArchitecture = "ProcessorArchitecture"
        case instructionSet = "InstructionSet"
        case maxSpeedMHz = "MaxSpeedMHz"
        case totalCores = "TotalCores"
        case totalThreads = "TotalThreads"
        case socket = "Socket"
        case status = "Status"
    }
}

/// `/redfish/v1/Systems/<id>/Memory/<id>`
struct MemoryModule: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var manufacturer: String?
    var partNumber: String?
    var serialNumber: String?
    var deviceLocator: String?
    var memoryDeviceType: String?
    var capacityMiB: Double?
    var operatingSpeedMhz: Double?
    var rankCount: Int?
    var status: RedfishStatus?

    var id: String { odataID ?? idField ?? "unidentified" }
    var capacityGiB: Double? { capacityMiB.map { $0 / 1024 } }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case manufacturer = "Manufacturer"
        case partNumber = "PartNumber"
        case serialNumber = "SerialNumber"
        case deviceLocator = "DeviceLocator"
        case memoryDeviceType = "MemoryDeviceType"
        case capacityMiB = "CapacityMiB"
        case operatingSpeedMhz = "OperatingSpeedMhz"
        case rankCount = "RankCount"
        case status = "Status"
    }
}

/// `/redfish/v1/Systems/<id>/EthernetInterfaces/<id>`
struct EthernetInterface: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var macAddress: String?
    var permanentMACAddress: String?
    var speedMbps: Double?
    var fullDuplex: Bool?
    var linkStatus: String?
    var interfaceEnabled: Bool?
    var hostName: String?
    var status: RedfishStatus?

    var id: String { odataID ?? idField ?? "unidentified" }
    var mac: String? { macAddress ?? permanentMACAddress }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case macAddress = "MACAddress"
        case permanentMACAddress = "PermanentMACAddress"
        case speedMbps = "SpeedMbps"
        case fullDuplex = "FullDuplex"
        case linkStatus = "LinkStatus"
        case interfaceEnabled = "InterfaceEnabled"
        case hostName = "HostName"
        case status = "Status"
    }
}
