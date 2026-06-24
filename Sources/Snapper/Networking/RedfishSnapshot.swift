import Foundation

/// An immutable point-in-time view of a server's Redfish data, consumed by the UI.
struct RedfishSnapshot {
    var serviceRoot: ServiceRoot?
    var system: ComputerSystem?
    var chassis: Chassis?
    var thermal: Thermal?
    var power: Power?
    var manager: Manager?
    var storage: [StorageSubsystem]
    var drives: [Drive]
    var processors: [Processor]
    var memory: [MemoryModule]
    var ethernet: [EthernetInterface]
    var capturedAt: Date

    init(serviceRoot: ServiceRoot? = nil,
         system: ComputerSystem? = nil,
         chassis: Chassis? = nil,
         thermal: Thermal? = nil,
         power: Power? = nil,
         manager: Manager? = nil,
         storage: [StorageSubsystem] = [],
         drives: [Drive] = [],
         processors: [Processor] = [],
         memory: [MemoryModule] = [],
         ethernet: [EthernetInterface] = [],
         capturedAt: Date = Date()) {
        self.serviceRoot = serviceRoot
        self.system = system
        self.chassis = chassis
        self.thermal = thermal
        self.power = power
        self.manager = manager
        self.storage = storage
        self.drives = drives
        self.processors = processors
        self.memory = memory
        self.ethernet = ethernet
        self.capturedAt = capturedAt
    }

    /// Overall health derived from the system, chassis, and BMC.
    var overallHealth: RedfishHealth {
        let healths = [
            system?.status?.effectiveHealth,
            chassis?.status?.effectiveHealth,
            manager?.status?.effectiveHealth
        ].compactMap { $0 }
        if healths.contains(.critical) { return .critical }
        if healths.contains(.warning) { return .warning }
        if healths.contains(.ok) { return .ok }
        return .unknown
    }

    /// Vendor string, used to choose vendor-specific UI templates.
    var vendor: String {
        let candidates = [
            serviceRoot?.vendor,
            system?.manufacturer,
            chassis?.manufacturer,
            manager?.name
        ].compactMap { $0?.lowercased() }
        if candidates.contains(where: { $0.contains("dell") }) { return "Dell" }
        if candidates.contains(where: { $0.contains("hpe") || $0.contains("hewlett") }) { return "HPE" }
        if candidates.contains(where: { $0.contains("lenovo") }) { return "Lenovo" }
        return serviceRoot?.vendor ?? system?.manufacturer ?? "Generic"
    }

    var isDell: Bool { vendor == "Dell" }
}

/// A historical sample for trend charts.
struct MetricSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let powerWatts: Double?
    let inletTempC: Double?
    let cpuTempC: Double?
    let maxFanPercent: Double?
}
