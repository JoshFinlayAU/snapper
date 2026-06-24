import Foundation
import Combine
import SwiftUI

/// One connected server tab. Owns its Redfish client, latest snapshot, polling timer,
/// and metric history for trend charts.
@MainActor
final class ServerConnection: ObservableObject, Identifiable {
    let id: UUID
    let server: SavedServer

    enum Phase: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var snapshot: RedfishSnapshot?
    @Published var logs: [LogEntry] = []
    @Published var history: [MetricSample] = []
    @Published var lastError: String?
    @Published var isRefreshing = false
    @Published var actionInFlight = false
    @Published var actionMessage: String?
    @Published var autoRefresh = true

    // On-demand resources (fetched when their views appear, not on every poll).
    @Published var virtualMedia: [VirtualMediaDevice] = []
    @Published var biosAttributes: [String: JSONValue] = [:]
    @Published var biosRegistry: [String: BiosAttributeDef] = [:]
    @Published var managerAttributes: [String: JSONValue] = [:]
    @Published var networkAdapters: [NetworkAdapterDetail] = []
    @Published var isLoadingExtras = false
    @Published var isLoadingNetwork = false

    private var service: RedfishService?
    private var serviceRoot: ServiceRoot?
    private var pollingTask: Task<Void, Never>?
    private let maxHistory = 60
    let refreshInterval: TimeInterval = 10

    init(server: SavedServer, password: String) {
        self.id = server.id
        self.server = server
        self.password = password
    }

    private let password: String

    var title: String { server.name }

    // MARK: - Lifecycle

    func connect() async {
        // Cancel any in-flight polling from a previous connection attempt.
        pollingTask?.cancel()
        pollingTask = nil
        phase = .connecting
        lastError = nil
        do {
            let client = try RedfishClient(
                host: server.host,
                port: server.port,
                username: server.username,
                password: password,
                allowSelfSigned: server.allowSelfSigned
            )
            let service = RedfishService(client: client)
            self.service = service
            let root = try await service.connect()
            self.serviceRoot = root
            try await refreshSnapshot(initial: true)
            phase = .connected
            startPolling()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = .failed(message)
            lastError = message
        }
    }

    func disconnect() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Refresh

    func refresh() async {
        guard !isRefreshing else { return }
        await refreshSafely(initial: false)
    }

    private func refreshSafely(initial: Bool) async {
        do {
            try await refreshSnapshot(initial: initial)
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func refreshSnapshot(initial: Bool) async throws {
        guard let service, let root = serviceRoot else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let snap = try await service.fetchSnapshot(root: root)
        self.snapshot = snap
        recordSample(from: snap)

        // Logs are heavier; fetch on initial connect and refresh opportunistically.
        if let manager = snap.manager {
            if let entries = try? await service.fetchManagerLog(manager: manager) {
                self.logs = entries
            }
        }
    }

    private func recordSample(from snap: RedfishSnapshot) {
        let power = snap.power?.powerControl?.first?.powerConsumedWatts
        let inlet = snap.thermal?.temperatures?.first {
            ($0.physicalContext ?? "").localizedCaseInsensitiveContains("intake") ||
            ($0.name ?? "").localizedCaseInsensitiveContains("inlet")
        }?.readingCelsius
        let cpu = snap.thermal?.temperatures?.first {
            ($0.physicalContext ?? "").localizedCaseInsensitiveContains("cpu") ||
            ($0.name ?? "").localizedCaseInsensitiveContains("cpu")
        }?.readingCelsius
        let fan = snap.thermal?.fans?
            .compactMap { $0.fraction }
            .max()
            .map { $0 * 100 }

        let sample = MetricSample(
            timestamp: snap.capturedAt,
            powerWatts: power,
            inletTempC: inlet,
            cpuTempC: cpu,
            maxFanPercent: fan
        )
        history.append(sample)
        if history.count > maxHistory {
            history.removeFirst(history.count - maxHistory)
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask?.cancel()
        guard autoRefresh else { return }
        pollingTask = Task { [weak self] in
            guard let interval = self?.refreshInterval else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                guard self.autoRefresh, !self.isRefreshing else { continue }
                await self.refreshSafely(initial: false)
            }
        }
    }

    func setAutoRefresh(_ on: Bool) {
        autoRefresh = on
        if on { startPolling() } else { disconnect() }
    }

    // MARK: - Power actions

    func performReset(_ resetType: String) async {
        guard let service, let system = snapshot?.system else { return }
        actionInFlight = true
        actionMessage = nil
        defer { actionInFlight = false }
        do {
            try await service.resetSystem(system, resetType: resetType)
            actionMessage = "Sent \"\(resetType)\" — refreshing…"
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await refreshSafely(initial: false)
        } catch {
            actionMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Writable controls

    /// Run a PATCH-style control change, surfacing progress/result via `actionMessage`
    /// and refreshing the snapshot so the UI reflects the new state.
    private func performControl(_ successMessage: String, _ work: (RedfishService) async throws -> Void) async {
        guard let service else { return }
        actionInFlight = true
        actionMessage = nil
        defer { actionInFlight = false }
        do {
            try await work(service)
            actionMessage = successMessage
            await refreshSafely(initial: false)
        } catch {
            actionMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func setIdentify(_ on: Bool) async {
        guard let system = snapshot?.system else { return }
        await performControl(on ? "Identify LED on." : "Identify LED off.") {
            try await $0.setIdentify(system, on: on)
        }
    }

    func setBootOverride(target: String?, persistent: Bool) async {
        guard let system = snapshot?.system else { return }
        let message = target.map { "Next boot set to \($0)\(persistent ? " (persistent)" : "")." } ?? "Boot override cleared."
        await performControl(message) {
            try await $0.setBootOverride(system, target: target, persistent: persistent)
        }
    }

    func setAssetTag(_ tag: String) async {
        guard let system = snapshot?.system else { return }
        await performControl("Asset tag updated.") {
            try await $0.setAssetTag(system, tag: tag)
        }
    }

    func setPowerLimit(_ watts: Int?) async {
        guard let powerPath = snapshot?.chassis?.power?.odataID else { return }
        let message = watts.map { "Power cap set to \($0) W." } ?? "Power cap disabled."
        await performControl(message) {
            try await $0.setPowerLimit(powerPath: powerPath, watts: watts)
        }
    }

    // MARK: - Virtual media

    func loadVirtualMedia() async {
        guard let service, let manager = snapshot?.manager else { return }
        isLoadingExtras = true
        defer { isLoadingExtras = false }
        virtualMedia = await service.fetchVirtualMedia(manager: manager)
    }

    func mountMedia(_ device: VirtualMediaDevice, image: String, username: String?, password: String?) async {
        await performControl("Mounted \(image).") {
            try await $0.insertVirtualMedia(device, image: image, username: username, password: password)
        }
        await loadVirtualMedia()
    }

    func ejectMedia(_ device: VirtualMediaDevice) async {
        await performControl("Ejected \(device.kind) media.") {
            try await $0.ejectVirtualMedia(device)
        }
        await loadVirtualMedia()
    }

    // MARK: - Network adapters

    func loadNetworkAdapters() async {
        guard let service, let chassis = snapshot?.chassis else { return }
        isLoadingNetwork = true
        defer { isLoadingNetwork = false }
        networkAdapters = await service.fetchNetworkAdapters(chassis: chassis)
    }

    // MARK: - BIOS settings

    func loadBios() async {
        guard let service, let system = snapshot?.system else { return }
        isLoadingExtras = true
        defer { isLoadingExtras = false }
        // Fetch current values and the (large) registry concurrently.
        async let attrs = service.fetchBiosAttributes(system: system)
        async let registry = service.fetchBiosRegistry(system: system)
        biosAttributes = await attrs
        if biosRegistry.isEmpty, let reg = await registry {
            biosRegistry = reg.byName
        } else {
            _ = await registry
        }
    }

    func applyBiosChanges(_ changes: [String: Any]) async {
        guard let system = snapshot?.system else { return }
        await performControl("Staged \(changes.count) BIOS change(s) — applied on next reboot.") {
            try await $0.applyBiosSettings(system: system, changes: changes)
        }
        await loadBios()
    }

    // MARK: - iDRAC attributes (SNMP)

    func loadManagerAttributes() async {
        guard let service, let manager = snapshot?.manager else { return }
        isLoadingExtras = true
        defer { isLoadingExtras = false }
        managerAttributes = await service.fetchManagerAttributes(manager: manager)
    }

    func applyManagerChanges(_ changes: [String: Any], summary: String) async {
        guard let manager = snapshot?.manager else { return }
        await performControl(summary) {
            try await $0.applyManagerAttributes(manager: manager, changes: changes)
        }
        await loadManagerAttributes()
    }

    /// New static iDRAC IP the user just applied, when it differs from the saved server's
    /// address — surfaced so the UI can offer to update the server entry and reconnect.
    @Published var suggestedIPUpdate: String?

    func applyNetworkChanges(_ changes: [String: Any], newStaticIP: String?) async {
        await applyManagerChanges(changes, summary: "Applied \(changes.count) network setting\(changes.count == 1 ? "" : "s") — iDRAC may briefly drop its connection.")
        if let ip = newStaticIP?.trimmingCharacters(in: .whitespaces), !ip.isEmpty, ip != server.bareHost {
            suggestedIPUpdate = ip
        }
    }

    // MARK: - RAID configuration

    func createVolume(volumesPath: String, raidType: String, name: String, driveODataIDs: [String]) async {
        await performControl("Creating \(raidType) virtual disk — a config job was queued.") {
            try await $0.createVolume(volumesPath: volumesPath, raidType: raidType, name: name, driveODataIDs: driveODataIDs)
        }
    }

    func deleteVolume(_ volume: Volume) async {
        await performControl("Deleting \(volume.title) — a config job was queued.") {
            try await $0.deleteVolume(volume)
        }
    }

    func locateDrive(_ drive: Drive, on: Bool) async {
        guard let system = snapshot?.system, let fqdd = drive.fqdd else { return }
        await performControl(on ? "Blinking \(drive.model ?? "drive") locate LED." : "Stopped locate LED.") {
            try await $0.locateDrive(system: system, driveFQDD: fqdd, on: on)
        }
    }

    func convertDrive(_ drive: Drive, toRAID: Bool) async {
        guard let system = snapshot?.system, let fqdd = drive.fqdd else { return }
        let what = drive.model ?? "drive"
        await performControl(toRAID ? "Converting \(what) to RAID — job queued." : "Converting \(what) to Non-RAID — job queued.") {
            try await $0.convertDrives(system: system, driveFQDDs: [fqdd], toRAID: toRAID)
        }
    }

    // MARK: - VNC (virtual console)

    func enableVNC(port: Int, password: String) async {
        var changes: [String: Any] = [
            "VNCServer.1.Enable": "Enabled",
            "VNCServer.1.Port": port
        ]
        if !password.isEmpty { changes["VNCServer.1.Password"] = password }
        await applyManagerChanges(changes, summary: "VNC server enabled on port \(port).")
    }

    func disableVNC() async {
        await applyManagerChanges(["VNCServer.1.Enable": "Disabled"], summary: "VNC server disabled.")
    }
}
