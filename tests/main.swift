import Foundation

// Standalone decoding test runner for the Redfish model layer.
// Compiled together with the model sources by tests/run.sh (Command Line Tools
// lacks XCTest, so this avoids `swift test`). Exits non-zero on any failure.

var failures = 0
var passed = 0

func check(_ condition: Bool, _ name: String, _ detail: String = "") {
    if condition {
        passed += 1
    } else {
        failures += 1
        FileHandle.standardError.write(Data("✗ FAIL: \(name) \(detail)\n".utf8))
    }
}

func decode<T: Decodable>(_ json: String, as type: T.Type) -> T? {
    do { return try JSONDecoder().decode(T.self, from: Data(json.utf8)) }
    catch {
        FileHandle.standardError.write(Data("decode error for \(T.self): \(error)\n".utf8))
        return nil
    }
}

// ServiceRoot
if let root = decode(Fixtures.serviceRoot, as: ServiceRoot.self) {
    check(root.product == "Integrated Dell Remote Access Controller", "serviceRoot.product")
    check(root.vendor == "Dell", "serviceRoot.vendor")
    check(root.systems?.odataID == "/redfish/v1/Systems", "serviceRoot.systems")
    check(root.chassis?.odataID == "/redfish/v1/Chassis", "serviceRoot.chassis")
    check(root.managers?.odataID == "/redfish/v1/Managers", "serviceRoot.managers")
} else { check(false, "serviceRoot decodes") }

// ComputerSystem
if let sys = decode(Fixtures.computerSystem, as: ComputerSystem.self) {
    check(sys.manufacturer == "Dell Inc.", "system.manufacturer")
    check(sys.model == "PowerEdge R740", "system.model")
    check(sys.sku == "ABCD123", "system.sku")
    check(sys.isPoweredOn, "system.isPoweredOn")
    check(sys.status?.effectiveHealth == .ok, "system.health")
    check(sys.processorSummary?.count == 2, "system.cpuCount")
    check(sys.memorySummary?.totalSystemMemoryGiB == 384, "system.memGiB")
    check(sys.actions?.reset?.target == "/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset", "system.resetTarget")
    check(sys.actions?.reset?.allowableValues?.contains("GracefulShutdown") == true, "system.resetAllowable")
} else { check(false, "computerSystem decodes") }

// Health rollup preferred
if let status = decode(#"{"State":"Enabled","Health":"OK","HealthRollup":"Warning"}"#, as: RedfishStatus.self) {
    check(status.effectiveHealth == .warning, "status.rollupPreferred")
    check(status.isEnabled, "status.isEnabled")
} else { check(false, "status decodes") }

// Unknown health
if let status = decode(#"{"Health":"Frobnicated"}"#, as: RedfishStatus.self) {
    check(status.health == .unknown, "status.unknownHealth")
} else { check(false, "unknown health decodes") }

// Thermal
if let thermal = decode(Fixtures.thermal, as: Thermal.self) {
    check(thermal.temperatures?.count == 2, "thermal.tempCount")
    let inlet = thermal.temperatures?.first { $0.name == "Inlet Temp" }
    check(inlet?.readingCelsius == 22, "thermal.inletReading")
    check(inlet?.fraction != nil, "thermal.inletFraction")
    let fan = thermal.fans?.first
    check(fan?.reading == 7680, "thermal.fanReading")
    check(fan?.fraction != nil, "thermal.fanFraction")
} else { check(false, "thermal decodes") }

// Power
if let power = decode(Fixtures.power, as: Power.self) {
    check(power.powerControl?.first?.powerConsumedWatts == 210, "power.consumed")
    check(power.powerControl?.first?.powerMetrics?.maxConsumedWatts == 300, "power.maxMetric")
    check(power.powerSupplies?.count == 2, "power.psuCount")
    check(power.powerSupplies?.first?.outputWatts == 105, "power.psuOutput")
    check(power.powerSupplies?.first?.powerCapacityWatts == 750, "power.psuCapacity")
} else { check(false, "power decodes") }

// Drive
if let drive = decode(Fixtures.drive, as: Drive.self) {
    check(drive.isSSD, "drive.isSSD")
    check(drive.capacityBytes == 960197124096, "drive.capacity")
    check(drive.failurePredicted == false, "drive.failurePredicted")
    check(drive.status?.effectiveHealth == .ok, "drive.health")
} else { check(false, "drive decodes") }

// Collection
if let collection = decode(#"{"Members":[{"@odata.id":"/redfish/v1/Systems/System.Embedded.1"}],"Members@odata.count":1}"#, as: RedfishCollection.self) {
    check(collection.count == 1, "collection.count")
    check(collection.members.first?.odataID == "/redfish/v1/Systems/System.Embedded.1", "collection.member")
} else { check(false, "collection decodes") }

// Snapshot derivations
if let sys = decode(Fixtures.computerSystem, as: ComputerSystem.self) {
    let snapshot = RedfishSnapshot(system: sys)
    check(snapshot.isDell, "snapshot.isDell")
    check(snapshot.overallHealth == .ok, "snapshot.overallHealth")
}

// LogEntry severity
if let entry = decode(#"{"Id":"1","Message":"Fan redundancy lost","Severity":"Critical","MessageId":"FAN0001"}"#, as: LogEntry.self) {
    check(entry.health == .critical, "logEntry.severity")
    check(entry.message == "Fan redundancy lost", "logEntry.message")
} else { check(false, "logEntry decodes") }

print("Model tests: \(passed) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
