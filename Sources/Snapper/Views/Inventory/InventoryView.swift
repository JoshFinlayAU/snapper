import SwiftUI

struct InventoryView: View {
    let snapshot: RedfishSnapshot

    var body: some View {
        VStack(spacing: 18) {
            identityCard
            if !snapshot.processors.isEmpty { processorsCard }
            if !snapshot.memory.isEmpty { memoryCard }
            if !snapshot.ethernet.isEmpty { networkCard }
        }
    }

    private var identityCard: some View {
        Card("System Identity", systemImage: "barcode.viewfinder") {
            let s = snapshot.system
            DetailRow(label: "Manufacturer", value: s?.manufacturer)
            DetailRow(label: "Model", value: s?.model)
            DetailRow(label: "Host Name", value: s?.hostName)
            DetailRow(label: "Serial Number", value: s?.serialNumber, mono: true)
            DetailRow(label: "Service Tag / SKU", value: s?.sku, mono: true)
            DetailRow(label: "Asset Tag", value: s?.assetTag)
            DetailRow(label: "BIOS Version", value: s?.biosVersion, mono: true)
            DetailRow(label: "UUID", value: s?.uuid, mono: true)
            if let mgr = snapshot.manager {
                DetailRow(label: "BMC Firmware", value: mgr.firmwareVersion, mono: true)
                DetailRow(label: "BMC Model", value: mgr.model)
            }
        }
    }

    private var processorsCard: some View {
        Card("Processors (\(snapshot.processors.count))", systemImage: "cpu.fill") {
            ForEach(snapshot.processors) { cpu in
                HStack {
                    StatusDot(health: cpu.status?.effectiveHealth ?? .unknown)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(cpu.model?.trimmingCharacters(in: .whitespaces) ?? cpu.name ?? "CPU")
                            .font(.subheadline.weight(.medium)).lineLimit(1)
                        Text("Socket \(cpu.socket ?? "—") · \(cpu.processorArchitecture ?? "")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(cpu.totalCores ?? 0)C / \(cpu.totalThreads ?? 0)T")
                            .font(.subheadline.weight(.semibold))
                        if let mhz = cpu.maxSpeedMHz {
                            Text(String(format: "%.1f GHz", mhz / 1000))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 3)
                Divider()
            }
        }
    }

    private var memoryCard: some View {
        Card("Memory (\(snapshot.memory.count) DIMMs)", systemImage: "memorychip.fill") {
            let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(snapshot.memory) { dimm in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            StatusDot(health: dimm.status?.effectiveHealth ?? .unknown)
                            Text(dimm.deviceLocator ?? dimm.name ?? "DIMM")
                                .font(.caption.weight(.semibold)).lineLimit(1)
                        }
                        Text(Fmt.gibFromGiB(dimm.capacityGiB))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.accent)
                        Text("\(Int(dimm.operatingSpeedMhz ?? 0)) MT/s · \(dimm.memoryDeviceType ?? "")")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
                }
            }
        }
    }

    private var networkCard: some View {
        Card("Network Interfaces (\(snapshot.ethernet.count))", systemImage: "network") {
            ForEach(snapshot.ethernet) { nic in
                HStack {
                    Image(systemName: nic.linkStatus == "LinkUp" ? "link" : "link.badge.plus")
                        .foregroundStyle(nic.linkStatus == "LinkUp" ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(nic.name ?? "NIC").font(.subheadline.weight(.medium))
                        Text(nic.mac ?? "—").font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let speed = nic.speedMbps {
                        Text(speed >= 1000 ? "\(Int(speed/1000)) Gb/s" : "\(Int(speed)) Mb/s")
                            .font(.caption.weight(.medium))
                    }
                    Text(nic.linkStatus ?? "—").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
                Divider()
            }
        }
    }
}
