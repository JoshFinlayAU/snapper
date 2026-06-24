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
    // Writable-control fields
    check(sys.assetTag == "ACME-DC1-R12", "system.assetTag")
    check(sys.indicatorLED == "Blinking", "system.indicatorLED")
    check(sys.isIdentifyActive, "system.isIdentifyActive")
    check(sys.boot?.bootSourceOverrideTarget == "Pxe", "system.bootTarget")
    check(sys.boot?.isOverrideActive == true, "system.bootOverrideActive")
    check(sys.boot?.allowableTargets?.contains("Pxe") == true, "system.bootAllowable")
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

// JSONValue scalar decoding + type-preserving coercion
if let attrs = decode(#"{"Attributes":{"SysProfile":"PerfOptimized","ProcCores":24,"BootSeqRetry":true,"FanSpeed":12.5}}"#, as: AttributeResource.self),
   let map = attrs.attributes {
    check(map["SysProfile"] == .string("PerfOptimized"), "json.string")
    check(map["ProcCores"] == .int(24), "json.int")
    check(map["BootSeqRetry"] == .bool(true), "json.bool")
    check(map["FanSpeed"] == .double(12.5), "json.double")
    check(map["ProcCores"]?.display == "24", "json.intDisplay")
    // Type-preserving coercion for PATCH payloads
    check(JSONValue.int(1).coerced(from: "48") as? Int == 48, "json.coerceInt")
    check(JSONValue.bool(false).coerced(from: "true") as? Bool == true, "json.coerceBool")
    check(JSONValue.string("x").coerced(from: "Disabled") as? String == "Disabled", "json.coerceString")
} else { check(false, "attributeResource decodes") }

// VirtualMedia device with inline action targets
if let vm = decode(Fixtures.virtualMedia, as: VirtualMediaDevice.self) {
    check(vm.isInserted, "vm.inserted")
    check(vm.image == "//host/share/win.iso", "vm.image")
    check(vm.kind.contains("CD/DVD"), "vm.kind")
    check(vm.insertTarget?.hasSuffix("VirtualMedia.InsertMedia") == true, "vm.insertTarget")
    check(vm.ejectTarget?.hasSuffix("VirtualMedia.EjectMedia") == true, "vm.ejectTarget")
} else { check(false, "virtualMedia decodes") }

// VirtualMedia fallback targets when Actions is absent
if let vm = decode(#"{"@odata.id":"/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD","Id":"CD","Inserted":false}"#, as: VirtualMediaDevice.self) {
    check(vm.isInserted == false, "vm.notInserted")
    check(vm.insertTarget == "/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD/Actions/VirtualMedia.InsertMedia", "vm.fallbackInsert")
} else { check(false, "virtualMedia fallback decodes") }

// NetworkAdapter hardware
if let adapter = decode(Fixtures.networkAdapter, as: NetworkAdapter.self) {
    check(adapter.manufacturer == "Broadcom Inc. and subsidiaries", "nic.manufacturer")
    check(adapter.firmware == "22.91.5", "nic.firmware")
    check(adapter.displayModel == "BCM57504 NetXtreme-E", "nic.displayModel")
} else { check(false, "networkAdapter decodes") }

// NetworkAdapter displayModel falls back past generic "...View" names
if let adapter = decode(#"{"Id":"NIC.Embedded.1","Name":"Network Adapter View","Model":null}"#, as: NetworkAdapter.self) {
    check(adapter.displayModel == "NIC.Embedded.1", "nic.displayModelFallback")
} else { check(false, "networkAdapter fallback decodes") }

// NetworkPort link + speed
if let port = decode(Fixtures.networkPort, as: NetworkPort.self) {
    check(port.isUp, "port.isUp")
    check(port.currentLinkSpeedMbps == 25000, "port.currentSpeed")
    check(port.maxSupportedMbps == 25000, "port.maxSupported")
    check(port.mac == "B0:7B:25:00:11:22", "port.mac")
} else { check(false, "networkPort decodes") }

// Dell transceiver (SFP28 optic)
if let t = decode(Fixtures.transceiver, as: DellNetworkTransceiver.self) {
    check(t.vendor == "EMULEX", "xcvr.vendor")
    check(t.formFactor == "SFP/SFP+/SFP28", "xcvr.formFactor")
    check(t.isOptical, "xcvr.isOptical")
    check(t.part == "AFBR-57F5MZ-ELX", "xcvr.part")
    check(t.serial == "AA1726J00HT", "xcvr.serial")
} else { check(false, "transceiver decodes") }

// Transceiver trims whitespace-only Revision to nil
if let t = decode(#"{"Id":"x","VendorName":"  ","Revision":" ","IdentifierType":"QSFP28","InterfaceType":"DirectAttachCopper"}"#, as: DellNetworkTransceiver.self) {
    check(t.vendor == nil, "xcvr.emptyVendorNil")
    check(t.isOptical == false, "xcvr.copperNotOptical")
} else { check(false, "transceiver copper decodes") }

// BIOS registry: typed defs, enum options, bounds, validation
if let reg = decode(Fixtures.biosRegistry, as: BiosRegistry.self) {
    let byName = reg.byName
    check(byName.count == 3, "bios.reg.count")
    if let boot = byName["BootMode"] {
        check(boot.kind == .enumeration, "bios.reg.enumKind")
        check(boot.optionLabel(for: "Uefi") == "UEFI", "bios.reg.optionLabel")
        check(boot.validationError(for: "Bios") == nil, "bios.reg.enumValid")
        check(boot.validationError(for: "Nope") != nil, "bios.reg.enumInvalid")
    } else { check(false, "bios.reg.boot present") }
    if let mem = byName["MemTest"] {
        check(mem.kind == .integer, "bios.reg.intKind")
        check(mem.validationError(for: "5") == nil, "bios.reg.intValid")
        check(mem.validationError(for: "999") != nil, "bios.reg.intOver")
        check(mem.validationError(for: "x") != nil, "bios.reg.intNaN")
        check(mem.coerced(from: "7") as? Int == 7, "bios.reg.intCoerce")
    } else { check(false, "bios.reg.mem present") }
    if let tag = byName["AssetTag"] {
        check(tag.readOnly == true, "bios.reg.readOnly")
        check(tag.validationError(for: "0123456789012345678901") != nil, "bios.reg.maxLen")
    } else { check(false, "bios.reg.tag present") }
} else { check(false, "biosRegistry decodes") }

// BIOS registry tolerates a malformed entry instead of discarding everything
let mixedRegistry = #"""
{
  "RegistryEntries": {
    "Attributes": [
      { "AttributeName": "Good1", "DisplayName": "Good One", "Type": "String", "MenuPath": "./A" },
      { "AttributeName": "Bad", "DisplayName": "Bad", "Type": "Integer", "DisplayOrder": "not-a-number" },
      { "AttributeName": "Good2", "DisplayName": "Good Two", "Type": "Boolean", "MenuPath": "./B" }
    ]
  }
}
"""#
if let reg = decode(mixedRegistry, as: BiosRegistry.self) {
    let byName = reg.byName
    check(byName.count == 2, "bios.reg.lossySkipsBad", "got \(byName.count)")
    check(byName["Good1"] != nil && byName["Good2"] != nil, "bios.reg.lossyKeepsGood")
    check(byName["Bad"] == nil, "bios.reg.lossyDropsBad")
} else { check(false, "bios.reg.mixed decodes") }

// DellNIC: optical transceiver populated
if let nic = decode(#"{"Id":"NIC.Slot.1-1-1","FQDD":"NIC.Slot.1-1-1","MediaType":"SFP_PLUS","VendorName":"Intel Corp","TransceiverVendorName":"FINisar CORP ","TransceiverPartNumber":"FTLX8574D3BCL","TransceiverSerialNumber":"XYZ123"}"#, as: DellNIC.self) {
    check(nic.hasTransceiver, "dellNic.hasTransceiver")
    check(nic.isCopper == false, "dellNic.notCopper")
    check(nic.tVendor == "FINisar CORP", "dellNic.tVendorTrimmed")
    check(nic.media == "SFP_PLUS", "dellNic.media")
} else { check(false, "dellNic optical decodes") }

// DellNIC: Base-T copper with null transceiver fields
if let nic = decode(#"{"Id":"NIC.Embedded.1-1-1","MediaType":"Base T","TransceiverVendorName":null,"TransceiverPartNumber":"Not Available","TransceiverSerialNumber":null}"#, as: DellNIC.self) {
    check(nic.isCopper, "dellNic.copper")
    check(nic.hasTransceiver == false, "dellNic.copperNoTransceiver")
} else { check(false, "dellNic copper decodes") }

// Volume (RAID virtual disk)
if let vol = decode(#"{"@odata.id":"/redfish/v1/Systems/System.Embedded.1/Storage/RAID.Integrated.1-1/Volumes/Disk.Virtual.0","Id":"Disk.Virtual.0","Name":"VD0","RAIDType":"RAID1","CapacityBytes":960197124096,"Encrypted":false,"Status":{"Health":"OK"},"Links":{"Drives":[{"@odata.id":"/d/0"},{"@odata.id":"/d/1"}]}}"#, as: Volume.self) {
    check(vol.raidType == "RAID1", "volume.raidType")
    check(vol.driveCount == 2, "volume.driveCount")
    check(vol.title == "VD0", "volume.title")
    check(vol.status?.effectiveHealth == .ok, "volume.health")
} else { check(false, "volume decodes") }

// StorageController RAID capability
if let sub = decode(#"{"@odata.id":"/redfish/v1/Systems/System.Embedded.1/Storage/RAID.Integrated.1-1","Id":"RAID.Integrated.1-1","Name":"PERC H740P","StorageControllers":[{"Name":"PERC H740P Mini","Model":"PERC H740P Mini","FirmwareVersion":"51.16.0","SupportedRAIDTypes":["RAID0","RAID1","RAID5","RAID6","RAID10"],"CacheSummary":{"TotalCacheSizeMiB":8192}}]}"#, as: StorageSubsystem.self) {
    check(sub.raidController?.isRAIDCapable == true, "ctrl.isRAIDCapable")
    check(sub.raidController?.supportedRAIDTypes?.contains("RAID6") == true, "ctrl.raidTypes")
    check(sub.raidController?.cacheSummary?.totalCacheSizeMiB == 8192, "ctrl.cache")
    check(sub.volumesPath == "/redfish/v1/Systems/System.Embedded.1/Storage/RAID.Integrated.1-1/Volumes", "ctrl.volumesPath")
} else { check(false, "storageController RAID decodes") }

// BIOS menu name prettification
check(BiosMenuName.pretty("./BootSettingsRef") == "Boot Settings", "menu.boot", BiosMenuName.pretty("./BootSettingsRef"))
check(BiosMenuName.pretty("./IntegratedDevicesRef") == "Integrated Devices", "menu.integrated", BiosMenuName.pretty("./IntegratedDevicesRef"))
check(BiosMenuName.pretty("./MemSettingsRef") == "Memory Settings", "menu.mem", BiosMenuName.pretty("./MemSettingsRef"))
check(BiosMenuName.pretty("./ProcSettingsRef") == "Processor Settings", "menu.proc", BiosMenuName.pretty("./ProcSettingsRef"))
check(BiosMenuName.pretty("./SysProfileSettingsRef") == "System Profile Settings", "menu.sysprofile", BiosMenuName.pretty("./SysProfileSettingsRef"))

// Registry menu display names override prettification
if let reg = decode(#"{"RegistryEntries":{"Attributes":[],"Menus":[{"MenuName":"BootSettings","DisplayName":"Boot Settings","MenuPath":"./BootSettingsRef"}]}}"#, as: BiosRegistry.self) {
    check(reg.menuDisplayNames["./BootSettingsRef"] == "Boot Settings", "menu.displayNameMap")
} else { check(false, "biosRegistry menus decode") }

// RAID detection survives empty SupportedRAIDTypes (real PERC behaviour)
if let perc = decode(#"{"Id":"RAID.Integrated.1-1","StorageControllers":[{"Model":"PERC H730P Mini","SupportedRAIDTypes":[],"CacheSummary":{"TotalCacheSizeMiB":2048}}]}"#, as: StorageSubsystem.self) {
    check(perc.isRAID, "raid.percDetected")
} else { check(false, "perc decodes") }
if let ahci = decode(#"{"Id":"AHCI.Embedded.2-1","StorageControllers":[{"Model":"C620 SATA Controller [AHCI mode]","CacheSummary":{"TotalCacheSizeMiB":0}}]}"#, as: StorageSubsystem.self) {
    check(ahci.isRAID == false, "raid.ahciExcluded")
} else { check(false, "ahci decodes") }

// RawDevice passthrough is not a virtual disk
if let raw = decode(#"{"Id":"Disk.Bay.0","Name":"Solid State Disk 0:1:0","RAIDType":"None","VolumeType":"RawDevice"}"#, as: Volume.self) {
    check(raw.isVirtualDisk == false, "vol.rawNotVD")
    check(raw.raidLabel == "Non-RAID", "vol.rawLabel")
} else { check(false, "rawDevice decodes") }
if let vd = decode(#"{"Id":"Disk.Virtual.0","RAIDType":"RAID1","VolumeType":"Mirrored"}"#, as: Volume.self) {
    check(vd.isVirtualDisk, "vol.realVD")
} else { check(false, "realVD decodes") }

// DellNIC media prettification (SFF_CAGE → SFP+)
if let nic = decode(#"{"Id":"NIC.Integrated.1-1-1","MediaType":"SFF_CAGE"}"#, as: DellNIC.self) {
    check(nic.mediaPretty == "SFP+", "nic.sffCagePretty")
    check(nic.isPluggable, "nic.pluggable")
    check(nic.isCopper == false, "nic.sffNotCopper")
} else { check(false, "dellNic sff decodes") }

// BIOS grouping uses top-level menu segment
if let attr = decode(#"{"AttributeName":"PmEnable","Type":"Boolean","MenuPath":"./MemSettingsRef/PersistentMemorySettingRef"}"#, as: BiosAttributeDef.self) {
    check(attr.group == "MemSettingsRef", "bios.topLevelGroup", attr.group)
    check(BiosMenuName.pretty(attr.group) == "Memory Settings", "bios.topLevelPretty")
} else { check(false, "bios topLevel decodes") }

print("Model tests: \(passed) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
