import SwiftUI
import Charts

struct ThermalView: View {
    let snapshot: RedfishSnapshot
    let history: [MetricSample]

    private var temps: [Thermal.Temperature] {
        (snapshot.thermal?.temperatures ?? []).filter { $0.readingCelsius != nil }
    }
    private var fans: [Thermal.Fan] {
        (snapshot.thermal?.fans ?? []).filter { $0.reading != nil }
    }

    var body: some View {
        VStack(spacing: 18) {
            if temps.isEmpty && fans.isEmpty {
                EmptySection(icon: "thermometer.slash", text: "No thermal data reported by this server.")
            } else {
                if history.count >= 2 { trendCard }
                if !temps.isEmpty { temperatureCard }
                if !fans.isEmpty { fanCard }
            }
        }
    }

    private var trendCard: some View {
        Card("Temperature Trend", systemImage: "chart.xyaxis.line") {
            Chart(history) { sample in
                if let inlet = sample.inletTempC {
                    LineMark(x: .value("Time", sample.timestamp),
                             y: .value("°C", inlet),
                             series: .value("Sensor", "Inlet"))
                        .foregroundStyle(.cyan)
                        .interpolationMethod(.catmullRom)
                }
                if let cpu = sample.cpuTempC {
                    LineMark(x: .value("Time", sample.timestamp),
                             y: .value("°C", cpu),
                             series: .value("Sensor", "CPU"))
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartForegroundStyleScale(["Inlet": Color.cyan, "CPU": Color.red])
            .chartYAxisLabel("°C")
            .frame(height: 200)
        }
    }

    private var temperatureCard: some View {
        Card("Temperatures", systemImage: "thermometer.medium") {
            Chart(temps) { t in
                BarMark(
                    x: .value("°C", t.readingCelsius ?? 0),
                    y: .value("Sensor", t.name ?? t.id)
                )
                .foregroundStyle(Theme.tint(for: t.fraction ?? 0))
                .annotation(position: .trailing) {
                    Text(Fmt.temperature(t.readingCelsius))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxisLabel("°C")
            .frame(height: CGFloat(max(temps.count, 1) * 34 + 30))

            Divider().padding(.vertical, 4)

            ForEach(temps) { t in
                HStack {
                    if let s = t.status { StatusDot(health: s.effectiveHealth) }
                    Text(t.name ?? t.id).font(.subheadline)
                    Spacer()
                    if let crit = t.upperThresholdCritical {
                        Text("crit \(Fmt.temperature(crit))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(Fmt.temperature(t.readingCelsius))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.tint(for: t.fraction ?? 0))
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var fanCard: some View {
        Card("Fans", systemImage: "fanblades.fill") {
            ForEach(fans) { fan in
                VStack(spacing: 4) {
                    HStack {
                        Text(fan.displayName).font(.subheadline)
                        Spacer()
                        Text(fan.isPercent ? Fmt.percent(fan.reading) : Fmt.rpm(fan.reading))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.tint(for: fan.fraction ?? 0))
                    }
                    BarGauge(fraction: fan.fraction ?? 0)
                }
                .padding(.vertical, 3)
            }
        }
    }
}

struct EmptySection: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
