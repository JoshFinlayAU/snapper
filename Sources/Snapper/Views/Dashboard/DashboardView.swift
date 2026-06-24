import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var connection: ServerConnection
    let snapshot: RedfishSnapshot

    private let columns = [GridItem(.adaptive(minimum: 230), spacing: 14)]

    var body: some View {
        VStack(spacing: 18) {
            SystemHeaderCard(snapshot: snapshot)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(tiles) { tile in
                    StatTile(icon: tile.icon, title: tile.title, value: tile.value,
                             detail: tile.detail, tint: tile.tint)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                gaugesCard
                trendCard
            }

            PowerActionsCard(connection: connection, snapshot: snapshot)
        }
    }

    // MARK: - Tiles

    private struct Tile: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let value: String
        let detail: String?
        let tint: Color
    }

    private var tiles: [Tile] {
        let sys = snapshot.system
        let power = snapshot.power?.powerControl?.first?.powerConsumedWatts
        let inlet = inletTemp
        return [
            Tile(icon: "power", title: "Power State",
                 value: sys?.powerState ?? "—",
                 detail: sys?.bootProgress?.lastState,
                 tint: sys?.isPoweredOn == true ? .green : .gray),
            Tile(icon: "bolt.fill", title: "Power Draw",
                 value: Fmt.watts(power),
                 detail: snapshot.power?.powerControl?.first?.powerCapacityWatts.map { "of \(Fmt.watts($0))" },
                 tint: .yellow),
            Tile(icon: "cpu", title: "Processors",
                 value: "\(sys?.processorSummary?.count ?? snapshot.processors.count)",
                 detail: sys?.processorSummary?.model?.trimmingCharacters(in: .whitespaces),
                 tint: .blue),
            Tile(icon: "memorychip", title: "Memory",
                 value: Fmt.gibFromGiB(sys?.memorySummary?.totalSystemMemoryGiB),
                 detail: "\(snapshot.memory.count) modules",
                 tint: .purple),
            Tile(icon: "internaldrive", title: "Drives",
                 value: "\(snapshot.drives.count)",
                 detail: driveSummary,
                 tint: .teal),
            Tile(icon: "thermometer.medium", title: "Inlet Temp",
                 value: Fmt.temperature(inlet),
                 detail: snapshot.thermal?.fans?.isEmpty == false ? "\(snapshot.thermal?.fans?.count ?? 0) fans" : nil,
                 tint: .orange)
        ]
    }

    private var inletTemp: Double? {
        snapshot.thermal?.temperatures?.first {
            ($0.physicalContext ?? "").localizedCaseInsensitiveContains("intake") ||
            ($0.name ?? "").localizedCaseInsensitiveContains("inlet")
        }?.readingCelsius ?? snapshot.thermal?.temperatures?.first?.readingCelsius
    }

    private var driveSummary: String? {
        guard !snapshot.drives.isEmpty else { return nil }
        let total = snapshot.drives.compactMap { $0.capacityBytes }.reduce(0, +)
        return Fmt.gib(total)
    }

    // MARK: - Gauges

    private var gaugesCard: some View {
        Card("Live Metrics", systemImage: "gauge.with.dots.needle.67percent") {
            HStack(spacing: 24) {
                powerGauge
                tempGauge
                fanGauge
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var powerGauge: some View {
        let consumed = snapshot.power?.powerControl?.first?.powerConsumedWatts
        let capacity = snapshot.power?.powerControl?.first?.powerCapacityWatts
            ?? snapshot.power?.powerSupplies?.compactMap { $0.powerCapacityWatts }.reduce(0, +)
        let frac = (consumed ?? 0) / max(capacity ?? 1000, 1)
        return RadialGauge(
            fraction: frac,
            valueText: Fmt.watts(consumed),
            caption: "Power",
            subCaption: capacity.map { "max \(Int($0))W" }
        )
    }

    private var tempGauge: some View {
        let temps = snapshot.thermal?.temperatures ?? []
        let hottest = temps.max { ($0.readingCelsius ?? 0) < ($1.readingCelsius ?? 0) }
        return RadialGauge(
            fraction: hottest?.fraction ?? 0,
            valueText: Fmt.temperature(hottest?.readingCelsius),
            caption: "Hottest",
            subCaption: hottest?.name
        )
    }

    private var fanGauge: some View {
        let fans = snapshot.thermal?.fans ?? []
        let fastest = fans.max { ($0.fraction ?? 0) < ($1.fraction ?? 0) }
        return RadialGauge(
            fraction: fastest?.fraction ?? 0,
            valueText: Fmt.percent((fastest?.fraction ?? 0) * 100),
            caption: "Top Fan",
            subCaption: fastest?.displayName
        )
    }

    // MARK: - Trend

    private var trendCard: some View {
        Card("Power Trend", systemImage: "chart.line.uptrend.xyaxis") {
            if connection.history.count < 2 {
                placeholderTrend
            } else {
                Chart(connection.history) { sample in
                    if let w = sample.powerWatts {
                        AreaMark(x: .value("Time", sample.timestamp),
                                 y: .value("Watts", w))
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.accent.opacity(0.5), Theme.accent.opacity(0.02)],
                                               startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Time", sample.timestamp),
                                 y: .value("Watts", w))
                            .foregroundStyle(Theme.accent)
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxisLabel("Watts")
                .frame(height: 180)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var placeholderTrend: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Collecting samples…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }
}
