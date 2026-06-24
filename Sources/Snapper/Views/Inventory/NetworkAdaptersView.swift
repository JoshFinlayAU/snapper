import SwiftUI

/// Detailed physical NIC hardware: per adapter (brand/model/part/firmware), per port
/// (link, speed, MAC, technology), and per transceiver (SFP/QSFP optic or DAC details).
struct NetworkAdaptersCard: View {
    @ObservedObject var connection: ServerConnection

    var body: some View {
        Group {
            if connection.networkAdapters.isEmpty {
                Card("Network Adapters", systemImage: "network") {
                    HStack(spacing: 8) {
                        if connection.isLoadingNetwork { ProgressView().controlSize(.small) }
                        Text(connection.isLoadingNetwork
                             ? "Probing NIC hardware and transceivers…"
                             : "No physical network adapters reported by the chassis.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(connection.networkAdapters) { detail in
                    AdapterCard(detail: detail)
                }
            }
        }
        .task(id: connection.id) {
            if connection.networkAdapters.isEmpty { await connection.loadNetworkAdapters() }
        }
    }
}

private struct AdapterCard: View {
    let detail: NetworkAdapterDetail
    private var adapter: NetworkAdapter { detail.adapter }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                header
                DetailGrid(pairs: [
                    ("Manufacturer", adapter.manufacturer),
                    ("Model", adapter.model),
                    ("Part Number", adapter.partNumber),
                    ("Serial Number", adapter.serialNumber),
                    ("Firmware", adapter.firmware),
                    ("SKU", adapter.sku)
                ])

                if detail.ports.isEmpty {
                    Text("No port data available.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Divider()
                    ForEach(detail.ports) { port in
                        PortRow(detail: port)
                        if port.id != detail.ports.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "network")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(adapter.displayModel)
                    .font(.headline)
                Text(adapter.idField ?? "")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HealthBadge(health: adapter.status?.effectiveHealth ?? .unknown)
        }
    }
}

private struct PortRow: View {
    let detail: NetworkPortDetail
    private var port: NetworkPort { detail.port }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: port.isUp ? "link" : "link.badge.plus")
                    .foregroundStyle(port.isUp ? .green : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Port \(port.physicalPortNumber ?? port.idField ?? "")")
                        .font(.subheadline.weight(.medium))
                    if let mac = port.mac {
                        Text(mac).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(speedText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(port.isUp ? .primary : .secondary)
                    Text(port.activeLinkTechnology ?? port.linkStatus ?? "—")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let nic = detail.nic {
                MediaInfo(nic: nic)
            }
            ForEach(detail.transceivers) { t in
                TransceiverChip(transceiver: t)
            }
        }
        .padding(.vertical, 3)
    }

    private var speedText: String {
        if port.isUp, let cur = port.currentLinkSpeedMbps, cur > 0 { return Self.mbps(cur) }
        if let maxCap = port.maxSupportedMbps, maxCap > 0 { return "\(Self.mbps(maxCap)) max" }
        return port.isUp ? "Up" : "Down"
    }

    static func mbps(_ mbps: Double) -> String {
        if mbps >= 1000 {
            let g = mbps / 1000
            return g == g.rounded() ? "\(Int(g)) Gb/s" : String(format: "%.1f Gb/s", g)
        }
        return "\(Int(mbps)) Mb/s"
    }
}

/// Media + pluggable-transceiver details sourced from the Dell per-function NIC view.
private struct MediaInfo: View {
    let nic: DellNIC

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(nic.isCopper ? Color.orange : Color.purple)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let media = nic.mediaPretty {
                        Text(media)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                if nic.hasTransceiver {
                    Text(transceiverLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .padding(.leading, 26)
    }

    private var icon: String { nic.isCopper ? "cable.connector" : "fibrechannel" }

    /// Context line: copper has no module; a pluggable cage without EEPROM data means the
    /// iDRAC didn't read the transceiver (common for some NIC/firmware combos).
    private var subtitle: String {
        if nic.hasTransceiver { return "transceiver" }
        if nic.isCopper { return "RJ45 · no transceiver" }
        if nic.isPluggable { return "module details not reported by iDRAC" }
        return ""
    }

    private var transceiverLine: String {
        var parts: [String] = []
        if let v = nic.tVendor { parts.append(v) }
        if let p = nic.tPart { parts.append("P/N \(p)") }
        if let s = nic.tSerial { parts.append("S/N \(s)") }
        return parts.isEmpty ? "Transceiver installed" : parts.joined(separator: "  ·  ")
    }
}

private struct TransceiverChip: View {
    let transceiver: DellNetworkTransceiver

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: transceiver.isOptical ? "fibrechannel" : "cable.connector")
                .foregroundStyle(transceiver.isOptical ? Color.purple : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let ff = transceiver.formFactor {
                        Text(ff)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    if let media = transceiver.interfaceType {
                        Text(media).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text(transceiverLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .padding(.leading, 26)
    }

    private var transceiverLine: String {
        var parts: [String] = []
        if let v = transceiver.vendor { parts.append(v) }
        if let p = transceiver.part { parts.append("P/N \(p)") }
        if let s = transceiver.serial { parts.append("S/N \(s)") }
        return parts.isEmpty ? "Transceiver" : parts.joined(separator: "  ·  ")
    }
}

/// A compact two-column grid of label/value pairs, skipping empty values.
private struct DetailGrid: View {
    let pairs: [(String, String?)]

    private var shown: [(String, String)] {
        pairs.compactMap { label, value in
            guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return (label, value)
        }
    }

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 200), spacing: 10)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(shown, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.caption2).foregroundStyle(.secondary)
                    Text(value).font(.caption.weight(.medium)).textSelection(.enabled)
                }
            }
        }
    }
}
