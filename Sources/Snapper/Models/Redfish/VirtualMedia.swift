import Foundation

/// `/redfish/v1/Managers/<id>/VirtualMedia/<id>` — a virtual CD/DVD or removable-disk slot
/// into which a remote image (ISO/IMG over HTTP/HTTPS/CIFS/NFS) can be mounted.
struct VirtualMediaDevice: Codable, Identifiable {
    let odataID: String?
    var idField: String?
    var name: String?
    var image: String?
    var imageName: String?
    var inserted: Bool?
    var connectedVia: String?
    var writeProtected: Bool?
    var mediaTypes: [String]?
    var actions: Actions?

    var id: String { odataID ?? idField ?? "vm" }
    var isInserted: Bool { inserted ?? false }

    /// Friendly device kind, e.g. "CD/DVD" or "Removable Disk".
    var kind: String {
        if let types = mediaTypes, !types.isEmpty {
            return types.map { $0 == "CD" || $0 == "DVD" ? "CD/DVD" : $0 }.joined(separator: ", ")
        }
        return name ?? idField ?? "Virtual Media"
    }

    struct Actions: Codable {
        var insert: VMAction?
        var eject: VMAction?
        enum CodingKeys: String, CodingKey {
            case insert = "#VirtualMedia.InsertMedia"
            case eject = "#VirtualMedia.EjectMedia"
        }
    }

    struct VMAction: Codable {
        var target: String?
    }

    enum CodingKeys: String, CodingKey {
        case odataID = "@odata.id"
        case idField = "Id"
        case name = "Name"
        case image = "Image"
        case imageName = "ImageName"
        case inserted = "Inserted"
        case connectedVia = "ConnectedVia"
        case writeProtected = "WriteProtected"
        case mediaTypes = "MediaTypes"
        case actions = "Actions"
    }

    var insertTarget: String? {
        actions?.insert?.target ?? odataID.map { $0 + "/Actions/VirtualMedia.InsertMedia" }
    }

    var ejectTarget: String? {
        actions?.eject?.target ?? odataID.map { $0 + "/Actions/VirtualMedia.EjectMedia" }
    }
}
