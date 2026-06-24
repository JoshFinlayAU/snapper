import Foundation

/// `/redfish/v1/Chassis/<id>/Thermal` — temperatures and fans.
struct Thermal: Codable {
    var temperatures: [Temperature]?
    var fans: [Fan]?

    enum CodingKeys: String, CodingKey {
        case temperatures = "Temperatures"
        case fans = "Fans"
    }

    struct Temperature: Codable, Identifiable {
        var memberID: String?
        var name: String?
        var readingCelsius: Double?
        var upperThresholdCritical: Double?
        var upperThresholdNonCritical: Double?
        var upperThresholdFatal: Double?
        var physicalContext: String?
        var status: RedfishStatus?

        var id: String { memberID ?? name ?? physicalContext ?? "temperature" }

        enum CodingKeys: String, CodingKey {
            case memberID = "MemberId"
            case name = "Name"
            case readingCelsius = "ReadingCelsius"
            case upperThresholdCritical = "UpperThresholdCritical"
            case upperThresholdNonCritical = "UpperThresholdNonCritical"
            case upperThresholdFatal = "UpperThresholdFatal"
            case physicalContext = "PhysicalContext"
            case status = "Status"
        }

        /// 0.0–1.0 fraction of the critical threshold, for gauges.
        var fraction: Double? {
            guard let reading = readingCelsius,
                  let limit = upperThresholdCritical ?? upperThresholdFatal,
                  limit > 0 else { return nil }
            return min(reading / limit, 1.0)
        }
    }

    struct Fan: Codable, Identifiable {
        var memberID: String?
        var name: String?
        var fanName: String?
        var reading: Double?
        var readingUnits: String?
        var minReadingRange: Double?
        var maxReadingRange: Double?
        var lowerThresholdCritical: Double?
        var status: RedfishStatus?

        var id: String { memberID ?? displayName }
        var displayName: String { name ?? fanName ?? "Fan" }

        enum CodingKeys: String, CodingKey {
            case memberID = "MemberId"
            case name = "Name"
            case fanName = "FanName"
            case reading = "Reading"
            case readingUnits = "ReadingUnits"
            case minReadingRange = "MinReadingRange"
            case maxReadingRange = "MaxReadingRange"
            case lowerThresholdCritical = "LowerThresholdCritical"
            case status = "Status"
        }

        var isPercent: Bool { (readingUnits ?? "").lowercased() == "percent" }

        var fraction: Double? {
            guard let reading else { return nil }
            if isPercent { return min(reading / 100.0, 1.0) }
            let maxRange = maxReadingRange ?? 18000
            guard maxRange > 0 else { return nil }
            return min(reading / maxRange, 1.0)
        }
    }
}
