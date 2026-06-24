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
        let (storage, drives) = await storageTask
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

    private func fetchStorage(system: ComputerSystem?) async -> ([StorageSubsystem], [Drive]) {
        guard let path = system?.storage?.odataID else { return ([], []) }
        guard let collection = try? await client.get(path, as: RedfishCollection.self) else { return ([], []) }
        var subsystems: [StorageSubsystem] = []
        var drives: [Drive] = []
        for ref in collection.members.prefix(16) {
            guard let sub = try? await client.get(ref.odataID, as: StorageSubsystem.self) else { continue }
            subsystems.append(sub)
            for driveRef in (sub.drives ?? []).prefix(64) {
                if let drive = try? await client.get(driveRef.odataID, as: Drive.self) {
                    drives.append(drive)
                }
            }
        }
        return (subsystems, drives)
    }
}
