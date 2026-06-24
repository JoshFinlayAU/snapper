import Foundation

/// `/redfish/v1/Chassis/<id>/Power` — power consumption, supplies, voltages.
struct Power: Codable {
    var powerControl: [PowerControl]?
    var powerSupplies: [PowerSupply]?
    var voltages: [Voltage]?

    enum CodingKeys: String, CodingKey {
        case powerControl = "PowerControl"
        case powerSupplies = "PowerSupplies"
        case voltages = "Voltages"
    }

    struct PowerControl: Codable, Identifiable {
        var memberID: String?
        var name: String?
        var powerConsumedWatts: Double?
        var powerCapacityWatts: Double?
        var powerMetrics: PowerMetrics?
        var powerLimit: PowerLimit?
        var status: RedfishStatus?

        var id: String { memberID ?? name ?? "member" }

        struct PowerMetrics: Codable {
            var intervalInMin: Double?
            var minConsumedWatts: Double?
            var maxConsumedWatts: Double?
            var averageConsumedWatts: Double?
            enum CodingKeys: String, CodingKey {
                case intervalInMin = "IntervalInMin"
                case minConsumedWatts = "MinConsumedWatts"
                case maxConsumedWatts = "MaxConsumedWatts"
                case averageConsumedWatts = "AverageConsumedWatts"
            }
        }

        struct PowerLimit: Codable {
            var limitInWatts: Double?
            var limitException: String?
            enum CodingKeys: String, CodingKey {
                case limitInWatts = "LimitInWatts"
                case limitException = "LimitException"
            }
        }

        enum CodingKeys: String, CodingKey {
            case memberID = "MemberId"
            case name = "Name"
            case powerConsumedWatts = "PowerConsumedWatts"
            case powerCapacityWatts = "PowerCapacityWatts"
            case powerMetrics = "PowerMetrics"
            case powerLimit = "PowerLimit"
            case status = "Status"
        }
    }

    struct PowerSupply: Codable, Identifiable {
        var memberID: String?
        var name: String?
        var model: String?
        var manufacturer: String?
        var serialNumber: String?
        var firmwareVersion: String?
        var powerCapacityWatts: Double?
        var lastPowerOutputWatts: Double?
        var lineInputVoltage: Double?
        var powerInputWatts: Double?
        var powerOutputWatts: Double?
        var efficiencyPercent: Double?
        var powerSupplyType: String?
        var status: RedfishStatus?

        var id: String { memberID ?? name ?? "member" }
        var outputWatts: Double? { lastPowerOutputWatts ?? powerOutputWatts }

        enum CodingKeys: String, CodingKey {
            case memberID = "MemberId"
            case name = "Name"
            case model = "Model"
            case manufacturer = "Manufacturer"
            case serialNumber = "SerialNumber"
            case firmwareVersion = "FirmwareVersion"
            case powerCapacityWatts = "PowerCapacityWatts"
            case lastPowerOutputWatts = "LastPowerOutputWatts"
            case lineInputVoltage = "LineInputVoltage"
            case powerInputWatts = "PowerInputWatts"
            case powerOutputWatts = "PowerOutputWatts"
            case efficiencyPercent = "EfficiencyPercent"
            case powerSupplyType = "PowerSupplyType"
            case status = "Status"
        }
    }

    struct Voltage: Codable, Identifiable {
        var memberID: String?
        var name: String?
        var readingVolts: Double?
        var upperThresholdCritical: Double?
        var lowerThresholdCritical: Double?
        var status: RedfishStatus?

        var id: String { memberID ?? name ?? "member" }

        enum CodingKeys: String, CodingKey {
            case memberID = "MemberId"
            case name = "Name"
            case readingVolts = "ReadingVolts"
            case upperThresholdCritical = "UpperThresholdCritical"
            case lowerThresholdCritical = "LowerThresholdCritical"
            case status = "Status"
        }
    }
}
