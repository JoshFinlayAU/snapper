import Foundation

/// `/redfish/v1/` — entry point of the Redfish service.
struct ServiceRoot: Codable {
    var id: String?
    var name: String?
    var redfishVersion: String?
    var uuid: String?
    var product: String?
    var vendor: String?

    var systems: ODataRef?
    var chassis: ODataRef?
    var managers: ODataRef?
    var sessionService: ODataRef?
    var updateService: ODataRef?
    var eventService: ODataRef?
    var links: Links?

    struct Links: Codable {
        var sessions: ODataRef?
        enum CodingKeys: String, CodingKey {
            case sessions = "Sessions"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case redfishVersion = "RedfishVersion"
        case uuid = "UUID"
        case product = "Product"
        case vendor = "Vendor"
        case systems = "Systems"
        case chassis = "Chassis"
        case managers = "Managers"
        case sessionService = "SessionService"
        case updateService = "UpdateService"
        case eventService = "EventService"
        case links = "Links"
    }
}
