import SwiftUI
import Charts

struct PowerView: View {
    @ObservedObject var connection: ServerConnection
    let snapshot: RedfishSnapshot

    private var power: Power? { snapshot.power }
    private var supplies: [Power.PowerSupply] { power?.powerSupplies ?? [] }

    var body: some View {
        VStack(spacing: 18) {
            if power == nil {
                EmptySection(icon: "bolt.slash", text: "No power data reported by this server.")
            } else {
                if let control = power?.powerControl?.first { summaryCard(control) }
                if !supplies.isEmpty { suppliesCard }
                PowerActionsCard(connection: connection, snapshot: snapshot)
            }
        }
    }

    private func summaryCard(_ control: Power.PowerControl) -> some View {
        Card("Power Consumption", systemImage: "bolt.fill") {
            HStack(spacing: 28) {
                RadialGauge(
                    fraction: (control.powerConsumedWatts ?? 0) / max(control.powerCapacityWatts ?? totalCapacity, 1),
                    valueText: Fmt.watts(control.powerConsumedWatts),
                    caption: "Now",
                    subCaption: "of \(Int(control.powerCapacityWatts ?? totalCapacity))W"
                )
                VStack(alignment: .leading, spacing: 10) {
                    metric("Average", control.powerMetrics?.averageConsumedWatts, .blue)
                    metric("Minimum", control.powerMetrics?.minConsumedWatts, .green)
                    metric("Maximum", control.powerMetrics?.maxConsumedWatts, .red)
                    if let limit = control.powerLimit?.limitInWatts {
                        metric("Cap Limit", limit, .purple)
                    }
                }
                Spacer()
            }
        }
    }

    private var totalCapacity: Double {
        supplies.compactMap { $0.powerCapacityWatts }.reduce(0, +)
    }

    private func metric(_ label: String, _ value: Double?, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 24)
            Text(Fmt.watts(value)).font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }

    private var suppliesCard: some View {
        Card("Power Supplies", systemImage: "powerplug.fill") {
            ForEach(supplies) { psu in
                VStack(spacing: 6) {
                    HStack {
                        StatusDot(health: psu.status?.effectiveHealth ?? .unknown)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(psu.name ?? "PSU").font(.subheadline.weight(.medium))
                            Text([psu.manufacturer, psu.model].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Fmt.watts(psu.outputWatts))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            if let cap = psu.powerCapacityWatts {
                                Text("max \(Int(cap))W").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let cap = psu.powerCapacityWatts, cap > 0 {
                        BarGauge(fraction: (psu.outputWatts ?? 0) / cap)
                    }
                    HStack(spacing: 14) {
                        if let v = psu.lineInputVoltage { miniStat("Input", "\(Int(v)) V") }
                        if let e = psu.efficiencyPercent { miniStat("Efficiency", Fmt.percent(e)) }
                        if let fw = psu.firmwareVersion { miniStat("Firmware", fw) }
                        Spacer()
                    }
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.medium))
        }
    }
}
