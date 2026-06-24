import Foundation

/// Orchestrates the chain of Redfish requests needed to build a `RedfishSnapshot`.
struct RedfishService {
    let client: RedfishClient

    /// Fetch the service root and validate the connection/credentials.
    func connect() async throws -> ServiceRoot {
        try await client.get("/redfish/v1/", as: ServiceRoot.self)
    }

    /// Build a full snapshot. Failures of optional sub-resources are tolerated so a
    /// partial server (or limited account) still yields a useful view.
    func fetchSnapshot(root: ServiceRoot) async throws -> RedfishSnapshot {
        async let systemTask = firstMember(of: root.systems?.odataID, as: ComputerSystem.self)
        async let chassisTask = firstMember(of: root.chassis?.odataID, as: Chassis.self)
        async let managerTask = firstMember(of: root.managers?.odataID, as: Manager.self)

        let system = try? await systemTask
        let chassis = try? await chassisTask
        let manager = try? await managerTask

        async let thermalTask = optional(chassis?.thermal?.odataID, as: Thermal.self)
        async let powerTask = optional(chassis?.power?.odataID, as: Power.self)
        async let storageTask = fetchStorage(system: system)
        async let cpuTask = fetchCollection(system?.processors?.odataID, as: Processor.self)
        async let memTask = fetchCollection(system?.memory?.odataID, as: MemoryModule.self)
        async let nicTask = fetchCollection(system?.ethernetInterfaces?.odataID, as: EthernetInterface.self)

        let thermal = await thermalTask
        let power = await powerTask
        let (storage, drives, volumes) = await storageTask
        let processors = await cpuTask
        let memory = await memTask
        let ethernet = await nicTask

        return RedfishSnapshot(
            serviceRoot: root,
            system: system,
            chassis: chassis,
            thermal: thermal,
            power: power,
            manager: manager,
            storage: storage,
            drives: drives,
            volumes: volumes,
            processors: processors,
            memory: memory,
            ethernet: ethernet
        )
    }

    // MARK: - Power actions

    func resetSystem(_ system: ComputerSystem, resetType: String) async throws {
        guard let target = system.actions?.reset?.target else {
            throw RedfishError.unsupportedAction
        }
        try await client.postAction(target, payload: ["ResetType": resetType])
    }

    // MARK: - Writable settings (PATCH)

    /// Toggle the chassis identify/locate indicator. Prefers the modern boolean
    /// property and falls back to the legacy `IndicatorLED` string for older BMCs.
    func setIdentify(_ system: ComputerSystem, on: Bool) async throws {
        guard let path = system.odataID else { throw RedfishError.unsupportedAction }
        let payload: [String: Any]
        if system.locationIndicatorActive != nil {
            payload = ["LocationIndicatorActive": on]
        } else {
            payload = ["IndicatorLED": on ? "Blinking" : "Off"]
        }
        try await client.patch(path, payload: payload)
    }

    /// Set (or clear) the one-time / persistent boot-source override.
    /// Pass `target == nil` to disable the override entirely.
    func setBootOverride(_ system: ComputerSystem, target: String?, persistent: Bool) async throws {
        guard let path = system.odataID else { throw RedfishError.unsupportedAction }
        var boot: [String: Any]
        if let target {
            boot = [
                "BootSourceOverrideEnabled": persistent ? "Continuous" : "Once",
                "BootSourceOverrideTarget": target
            ]
        } else {
            boot = ["BootSourceOverrideEnabled": "Disabled"]
        }
        try await client.patch(path, payload: ["Boot": boot])
    }

    /// Update the system asset tag.
    func setAssetTag(_ system: ComputerSystem, tag: String) async throws {
        guard let path = system.odataID else { throw RedfishError.unsupportedAction }
        try await client.patch(path, payload: ["AssetTag": tag])
    }

    /// Set the chassis power cap, or pass `watts == nil` to disable capping.
    func setPowerLimit(powerPath: String, watts: Int?) async throws {
        let limit: [String: Any] = ["LimitInWatts": watts.map { $0 as Any } ?? NSNull()]
        try await client.patch(powerPath, payload: ["PowerControl": [["PowerLimit": limit]]])
    }

    // MARK: - Virtual Media

    func fetchVirtualMedia(manager: Manager) async -> [VirtualMediaDevice] {
        guard let base = manager.odataID else { return [] }
        guard let collection = try? await client.get(base + "/VirtualMedia", as: RedfishCollection.self) else { return [] }
        var devices: [VirtualMediaDevice] = []
        for ref in collection.members.prefix(8) {
            if let device = try? await client.get(ref.odataID, as: VirtualMediaDevice.self) {
                devices.append(device)
            }
        }
        return devices
    }

    func insertVirtualMedia(_ device: VirtualMediaDevice, image: String, username: String?, password: String?) async throws {
        guard let target = device.insertTarget else { throw RedfishError.unsupportedAction }
        var payload: [String: Any] = ["Image": image, "Inserted": true, "WriteProtected": true]
        if let username, !username.isEmpty { payload["UserName"] = username }
        if let password, !password.isEmpty { payload["Password"] = password }
        try await client.postAction(target, payload: payload)
    }

    func ejectVirtualMedia(_ device: VirtualMediaDevice) async throws {
        guard let target = device.ejectTarget else { throw RedfishError.unsupportedAction }
        try await client.postAction(target, payload: [:])
    }

    // MARK: - Network adapters (hardware + transceivers)

    /// Walk Chassis → NetworkAdapters → NetworkPorts → Dell transceivers to build a detailed
    /// view of the physical NIC hardware. Tolerant of missing sub-resources.
    func fetchNetworkAdapters(chassis: Chassis) async -> [NetworkAdapterDetail] {
        guard let base = chassis.odataID else { return [] }
        guard let collection = try? await client.get(base + "/NetworkAdapters", as: RedfishCollection.self) else { return [] }

        var details: [NetworkAdapterDetail] = []
        for ref in collection.members.prefix(16) {
            guard let adapter = try? await client.get(ref.odataID, as: NetworkAdapter.self) else { continue }
            let ports = await fetchPorts(adapterPath: ref.odataID)
            details.append(NetworkAdapterDetail(id: adapter.id, adapter: adapter, ports: ports))
        }
        return details
    }

    private func fetchPorts(adapterPath: String) async -> [NetworkPortDetail] {
        // iDRAC exposes physical ports under NetworkPorts; fall back to the newer Ports.
        var collection = try? await client.get(adapterPath + "/NetworkPorts", as: RedfishCollection.self)
        if collection == nil {
            collection = try? await client.get(adapterPath + "/Ports", as: RedfishCollection.self)
        }
        guard let collection else { return [] }

        // Media/transceiver details live on the Dell per-function NIC view, keyed by port FQDD.
        let nicsByPort = await fetchDellNICs(adapterPath: adapterPath)

        var ports: [NetworkPortDetail] = []
        for ref in collection.members.prefix(16) {
            guard let port = try? await client.get(ref.odataID, as: NetworkPort.self) else { continue }
            let transceivers = await fetchTransceivers(portPath: ref.odataID)
            let nic = port.idField.flatMap { nicsByPort[$0] }
            ports.append(NetworkPortDetail(id: port.id, port: port, transceivers: transceivers, nic: nic))
        }
        return ports
    }

    /// Fetch each NetworkDeviceFunction's Dell NIC OEM view, keyed by the physical port FQDD
    /// (the function FQDD with its trailing partition segment removed).
    private func fetchDellNICs(adapterPath: String) async -> [String: DellNIC] {
        guard let collection = try? await client.get(adapterPath + "/NetworkDeviceFunctions", as: RedfishCollection.self) else { return [:] }
        var map: [String: DellNIC] = [:]
        for ref in collection.members.prefix(16) {
            guard let ndfId = ref.odataID.split(separator: "/").last.map(String.init) else { continue }
            let path = ref.odataID + "/Oem/Dell/DellNIC/" + ndfId
            guard let nic = try? await client.get(path, as: DellNIC.self) else { continue }
            let portFQDD = Self.portFQDD(fromFunction: nic.fqdd ?? nic.idField ?? ndfId)
            if map[portFQDD] == nil { map[portFQDD] = nic }
        }
        return map
    }

    /// "NIC.Embedded.2-1-1" (function) → "NIC.Embedded.2-1" (physical port).
    private static func portFQDD(fromFunction fqdd: String) -> String {
        guard let idx = fqdd.lastIndex(of: "-") else { return fqdd }
        return String(fqdd[..<idx])
    }

    private func fetchTransceivers(portPath: String) async -> [DellNetworkTransceiver] {
        guard let collection = try? await client.get(portPath + "/Oem/Dell/DellNetworkTransceivers", as: RedfishCollection.self) else { return [] }
        var result: [DellNetworkTransceiver] = []
        for ref in collection.members.prefix(4) {
            if let t = try? await client.get(ref.odataID, as: DellNetworkTransceiver.self) {
                result.append(t)
            }
        }
        return result
    }

    // MARK: - BIOS settings

    /// Current applied BIOS attributes (from `/Bios`).
    func fetchBiosAttributes(system: ComputerSystem) async -> [String: JSONValue] {
        guard let path = system.bios?.odataID else { return [:] }
        let resource = try? await client.get(path, as: AttributeResource.self)
        return resource?.attributes ?? [:]
    }

    /// The BIOS attribute registry (types, allowed enum values, bounds, read-only flags, menus).
    func fetchBiosRegistry(system: ComputerSystem) async -> BiosRegistry? {
        guard let path = system.bios?.odataID else { return nil }
        return try? await client.get(path + "/BiosRegistry", as: BiosRegistry.self)
    }

    /// Stage BIOS attribute changes via the `@Redfish.Settings` object; the BMC applies
    /// them on the next host reboot (or via a config job).
    func applyBiosSettings(system: ComputerSystem, changes: [String: Any]) async throws {
        guard let path = system.bios?.odataID else { throw RedfishError.unsupportedAction }
        try await client.patch(path + "/Settings", payload: ["Attributes": changes])
    }

    // MARK: - iDRAC attributes (SNMP, etc.)

    func fetchManagerAttributes(manager: Manager) async -> [String: JSONValue] {
        guard let base = manager.odataID else { return [:] }
        let resource = try? await client.get(base + "/Attributes", as: AttributeResource.self)
        return resource?.attributes ?? [:]
    }

    func applyManagerAttributes(manager: Manager, changes: [String: Any]) async throws {
        guard let base = manager.odataID else { throw RedfishError.unsupportedAction }
        try await client.patch(base + "/Attributes", payload: ["Attributes": changes])
    }

    // MARK: - Logs

    func fetchManagerLog(manager: Manager) async throws -> [LogEntry] {
        guard let logServicesPath = manager.logServices?.odataID else { return [] }
        let services: RedfishCollection = try await client.get(logServicesPath, as: RedfishCollection.self)
        // Prefer the SEL (System Event Log); fall back to the first available log.
        var chosen = services.members.first { $0.odataID.localizedCaseInsensitiveContains("sel") }
        chosen = chosen ?? services.members.first
        guard let logPath = chosen?.odataID else { return [] }
        let logService: LogService = try await client.get(logPath, as: LogService.self)
        guard let entriesPath = logService.entries?.odataID else { return [] }
        let collection: RedfishCollection = try await client.get(entriesPath, as: RedfishCollection.self)
        // Entry collections embed members inline for SEL; decode the full object.
        return try await fetchLogEntries(entriesPath, fallback: collection)
    }

    private func fetchLogEntries(_ path: String, fallback: RedfishCollection) async throws -> [LogEntry] {
        struct EntriesResponse: Decodable {
            let members: [LogEntry]?
            enum CodingKeys: String, CodingKey { case members = "Members" }
        }
        let resp: EntriesResponse = try await client.get(path, as: EntriesResponse.self)
        if let inline = resp.members, !inline.isEmpty {
            return Array(inline.prefix(200))
        }
        // Otherwise members are references; fetch up to 50 individually.
        var result: [LogEntry] = []
        for ref in fallback.members.prefix(50) {
            if let entry = try? await client.get(ref.odataID, as: LogEntry.self) {
                result.append(entry)
            }
        }
        return result
    }

    // MARK: - Helpers

    private func firstMember<T: Decodable>(of collectionPath: String?, as type: T.Type) async throws -> T? {
        guard let collectionPath else { return nil }
        let collection: RedfishCollection = try await client.get(collectionPath, as: RedfishCollection.self)
        guard let first = collection.members.first else { return nil }
        return try await client.get(first.odataID, as: T.self)
    }

    private func optional<T: Decodable>(_ path: String?, as type: T.Type) async -> T? {
        guard let path else { return nil }
        return try? await client.get(path, as: T.self)
    }

    private func fetchCollection<T: Decodable>(_ path: String?, as type: T.Type) async -> [T] {
        guard let path else { return [] }
        guard let collection = try? await client.get(path, as: RedfishCollection.self) else { return [] }
        var items: [T] = []
        for ref in collection.members.prefix(64) {
            if let item = try? await client.get(ref.odataID, as: T.self) {
                items.append(item)
            }
        }
        return items
    }

    private func fetchStorage(system: ComputerSystem?) async -> ([StorageSubsystem], [Drive], [Volume]) {
        guard let path = system?.storage?.odataID else { return ([], [], []) }
        guard let collection = try? await client.get(path, as: RedfishCollection.self) else { return ([], [], []) }
        var subsystems: [StorageSubsystem] = []
        var drives: [Drive] = []
        var volumes: [Volume] = []
        for ref in collection.members.prefix(16) {
            guard let sub = try? await client.get(ref.odataID, as: StorageSubsystem.self) else { continue }
            subsystems.append(sub)
            for driveRef in (sub.drives ?? []).prefix(64) {
                if let drive = try? await client.get(driveRef.odataID, as: Drive.self) {
                    drives.append(drive)
                }
            }
            if let vpath = sub.volumes?.odataID,
               let vcoll = try? await client.get(vpath, as: RedfishCollection.self) {
                for vref in vcoll.members.prefix(64) {
                    if let v = try? await client.get(vref.odataID, as: Volume.self) {
                        volumes.append(v)
                    }
                }
            }
        }
        return (subsystems, drives, volumes)
    }

    // MARK: - RAID configuration

    /// Create a RAID virtual disk on the given controller's Volumes collection.
    func createVolume(volumesPath: String, raidType: String, name: String, driveODataIDs: [String]) async throws {
        let drives = driveODataIDs.map { ["@odata.id": $0] }
        var payload: [String: Any] = ["RAIDType": raidType, "Links": ["Drives": drives]]
        if !name.isEmpty { payload["Name"] = name }
        try await client.postAction(volumesPath, payload: payload)
    }

    /// Delete a virtual disk.
    func deleteVolume(_ volume: Volume) async throws {
        guard let path = volume.odataID else { throw RedfishError.unsupportedAction }
        try await client.delete(path)
    }

    /// Blink (or stop blinking) a physical disk's locate LED via the Dell RAID service.
    func locateDrive(system: ComputerSystem, driveFQDD: String, on: Bool) async throws {
        guard let base = system.odataID else { throw RedfishError.unsupportedAction }
        let action = on ? "BlinkTarget" : "UnBlinkTarget"
        let path = base + "/Oem/Dell/DellRaidService/Actions/DellRaidService." + action
        try await client.postAction(path, payload: ["TargetFQDD": driveFQDD])
    }

    /// Convert physical disks between RAID-ready and Non-RAID (passthrough) state.
    func convertDrives(system: ComputerSystem, driveFQDDs: [String], toRAID: Bool) async throws {
        guard let base = system.odataID else { throw RedfishError.unsupportedAction }
        let action = toRAID ? "ConvertToRAID" : "ConvertToNonRAID"
        let path = base + "/Oem/Dell/DellRaidService/Actions/DellRaidService." + action
        try await client.postAction(path, payload: ["PDArray": driveFQDDs])
    }
}
