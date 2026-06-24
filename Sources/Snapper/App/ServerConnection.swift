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
}
