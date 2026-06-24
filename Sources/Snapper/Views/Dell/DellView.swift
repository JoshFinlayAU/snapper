import SwiftUI

/// A Dell iDRAC 9-specific template highlighting the BMC and Dell service identifiers.
struct DellView: View {
    let snapshot: RedfishSnapshot

    private var manager: Manager? { snapshot.manager }
    private var system: ComputerSystem? { snapshot.system }

    var body: some View {
        VStack(spacing: 18) {
            banner
            idracCard
            serviceCard
            healthRollupCard
        }
    }

    private var banner: some View {
        HStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dell iDRAC")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(manager?.model ?? "Integrated Dell Remote Access Controller")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            if let fw = manager?.firmwareVersion {
                VStack(alignment: .trailing) {
                    Text(fw).font(.title3.weight(.semibold)).foregroundStyle(.white)
                    Text("Firmware").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color(red: 0.0, green: 0.27, blue: 0.50), Color(red: 0.0, green: 0.45, blue: 0.70)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var idracCard: some View {
        Card("Management Controller", systemImage: "server.rack") {
            DetailRow(label: "Name", value: manager?.name)
            DetailRow(label: "Type", value: manager?.managerType)
            DetailRow(label: "Firmware Version", value: manager?.firmwareVersion, mono: true)
            DetailRow(label: "Controller Time", value: manager?.dateTime)
            DetailRow(label: "Power State", value: manager?.powerState)
            DetailRow(label: "UUID", value: manager?.uuid, mono: true)
        }
    }

    private var serviceCard: some View {
        Card("Dell Service Information", systemImage: "barcode") {
            DetailRow(label: "Service Tag", value: system?.sku, mono: true)
            DetailRow(label: "Express Service Code", value: expressServiceCode, mono: true)
            DetailRow(label: "Model", value: system?.model)
            DetailRow(label: "Serial Number", value: system?.serialNumber, mono: true)
            DetailRow(label: "Asset Tag", value: system?.assetTag)
            if let tag = system?.sku, !tag.isEmpty,
               let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "https://www.dell.com/support/home/en-us/product-support/servicetag/\(encoded)") {
                Link(destination: url) {
                    Label("Open Dell Support for \(tag)", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .padding(.top, 4)
            }
        }
    }

    /// Dell's Express Service Code is the decimal form of the base-36 Service Tag.
    private var expressServiceCode: String? {
        guard let tag = system?.sku?.uppercased(), !tag.isEmpty else { return nil }
        var value: UInt64 = 0
        let digits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for char in tag {
            guard let idx = digits.firstIndex(of: char) else { return nil }
            value = value * 36 + UInt64(idx)
        }
        return String(value)
    }

    private var healthRollupCard: some View {
        Card("Subsystem Health", systemImage: "heart.text.square.fill") {
            let rows: [(String, RedfishHealth?)] = [
                ("System", system?.status?.effectiveHealth),
                ("Processors", system?.processorSummary?.status?.effectiveHealth),
                ("Memory", system?.memorySummary?.status?.effectiveHealth),
                ("Chassis", snapshot.chassis?.status?.effectiveHealth),
                ("iDRAC", manager?.status?.effectiveHealth)
            ]
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0).font(.subheadline)
                    Spacer()
                    HealthBadge(health: row.1 ?? .unknown)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
