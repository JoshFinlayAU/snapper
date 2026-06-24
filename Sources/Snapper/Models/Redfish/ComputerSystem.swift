import Foundation

/// `/redfish/v1/Systems/<id>` — a logical computer system.
struct ComputerSystem: Codable, Identifiable {
    let odataID: String?
    var id: String { odataID ?? serialNumber ?? "system" }

    var idField: String?
    var name: String?
    var manufacturer: String?
    var model: String?
    var sku: String?
    var serialNumber: String?
    var partNumber: String?
    var assetTag: String?
    var hostName: String?
    var powerState: String?
    var biosVersion: String?
    var systemType: String?
    var uuid: String?
    var status: RedfishStatus?
    var indicatorLED: String?
    var locationIndicatorActive: Bool?
    var boot: Boot?

    var processorSummary: ProcessorSummary?
    var memorySummary: MemorySummary?
    var bootProgress: BootProgress?
    var trustedModules: [TrustedModule]?

    var processors: ODataRef?
    var memory: ODataRef?
    var storage: ODataRef?
    var ethernetInterfaces: ODataRef?
    var simpleStorage: ODataRef?
    var bios: ODataRef?
    var actions: Actions?

    struct ProcessorSummary: Codable {
        var count: Int?
        var model: String?
        var logicalProcessorCount: Int?
        var coreCount: Int?
        var status: RedfishStatus?
        enum CodingKeys: String, CodingKey {
            case count = "Count"
            case model = "Model"
            case logicalProcessorCount = "LogicalProcessorCount"
            case coreCount = "CoreCount"
            case status = "Status"
        }
    }

    struct MemorySummary: Codable {
        var totalSystemMemoryGiB: Double?
        var status: RedfishStatus?
        enum CodingKeys: String, CodingKey {
            case totalSystemMemoryGiB = "TotalSystemMemoryGiB"
            case status = "Status"
        }
    }

    struct BootProgress: Codable {
        var lastState: String?
        enum CodingKeys: String, CodingKey {
            case lastState = "LastState"
        }
    }

    struct TrustedModule: Codable {
        var status: RedfishStatus?
        var interfaceType: String?
        enum CodingKeys: String, CodingKey {
            case status = "Status"
            case interfaceType = "InterfaceType"
        }
    }

    /// Boot configuration, including the one-time/persistent boot-source override.
    struct Boot: Codable {
        var bootSourceOverrideEnabled: String?   // Disabled, Once, Continuous
        var bootSourceOverrideTarget: String?    // Pxe, Hdd, Cd, BiosSetup, Usb, …
        var bootSourceOverrideMode: String?      // Legacy, UEFI
        var allowableTargets: [String]?

        enum CodingKeys: String, CodingKey {
            case bootSourceOverrideEnabled = "BootSourceOverrideEnabled"
            case bootSourceOverrideTarget = "BootSourceOverrideTarget"
            case bootSourceOverrideMode = "BootSourceOverrideMode"
            case allowableTargets = "BootSourceOverrideTarget@Redfish.AllowableValues"
        }

        var isOverrideActive: Bool {
            guard let enabled = bootSourceOverrideEnabled else { return false }
            return enabled != "Disabled"
        }
    }

    struct Actions: Codable {
        var reset: ResetAction?
        enum CodingKeys: String, CodingKey {
            case reset = "#ComputerSystem.Reset"
        }
    }

    struct ResetAction: Codable {
        var target: String?
        var allowableValues: [String]?
        enum CodingKeys: String, CodingKey {
            case target = "target"
            case allowableValues = "ResetType@Redfish.AllowableValues"
        }
    }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case manufacturer = "Manufacturer"
        case model = "Model"
        case sku = "SKU"
        case serialNumber = "SerialNumber"
        case partNumber = "PartNumber"
        case assetTag = "AssetTag"
        case hostName = "HostName"
        case powerState = "PowerState"
        case biosVersion = "BiosVersion"
        case systemType = "SystemType"
        case uuid = "UUID"
        case status = "Status"
        case indicatorLED = "IndicatorLED"
        case locationIndicatorActive = "LocationIndicatorActive"
        case boot = "Boot"
        case processorSummary = "ProcessorSummary"
        case memorySummary = "MemorySummary"
        case bootProgress = "BootProgress"
        case trustedModules = "TrustedModules"
        case processors = "Processors"
        case memory = "Memory"
        case storage = "Storage"
        case ethernetInterfaces = "EthernetInterfaces"
        case simpleStorage = "SimpleStorage"
        case bios = "Bios"
        case actions = "Actions"
    }

    var isPoweredOn: Bool { powerState == "On" }

    /// Whether the chassis identify/locate indicator is currently active, using the
    /// modern boolean property when present and falling back to the legacy LED string.
    var isIdentifyActive: Bool {
        if let active = locationIndicatorActive { return active }
        return indicatorLED == "Blinking" || indicatorLED == "Lit"
    }
}
