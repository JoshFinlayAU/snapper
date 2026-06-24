import SwiftUI

struct StorageView: View {
    let snapshot: RedfishSnapshot

    var body: some View {
        VStack(spacing: 18) {
            if snapshot.storage.isEmpty && snapshot.drives.isEmpty {
                EmptySection(icon: "internaldrive", text: "No storage subsystems reported by this server.")
            } else {
                ForEach(snapshot.storage) { sub in
                    controllerCard(sub)
                }
                if !snapshot.drives.isEmpty { drivesCard }
            }
        }
    }

    private func controllerCard(_ sub: StorageSubsystem) -> some View {
        Card(sub.name ?? "Storage", systemImage: "externaldrive.connected.to.line.below.fill") {
            ForEach(Array((sub.storageControllers ?? []).enumerated()), id: \.offset) { _, ctrl in
                HStack {
                    StatusDot(health: ctrl.status?.effectiveHealth ?? .unknown)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ctrl.name ?? ctrl.model ?? "Controller").font(.subheadline.weight(.medium))
                        Text([ctrl.manufacturer, ctrl.model].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let fw = ctrl.firmwareVersion {
                        Text("FW \(fw)").font(.caption2).foregroundStyle(.secondary)
                    }
                    if let speed = ctrl.speedGbps {
                        Text("\(Int(speed)) Gb/s").font(.caption.weight(.medium))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var drivesCard: some View {
        Card("Physical Drives (\(snapshot.drives.count))", systemImage: "internaldrive.fill") {
            DriveTable(drives: snapshot.drives)
        }
    }
}

private struct DriveTable: View {
    let drives: [Drive]

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            ForEach(drives) { drive in
                row(drive)
                Divider()
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Drive").frame(maxWidth: .infinity, alignment: .leading)
            Text("Media").frame(width: 70, alignment: .leading)
            Text("Capacity").frame(width: 90, alignment: .trailing)
            Text("Bus").frame(width: 70, alignment: .leading)
            Text("Health").frame(width: 90, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }

    private func row(_ drive: Drive) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: drive.isSSD ? "memorychip" : "internaldrive")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(drive.model ?? drive.name ?? "Drive")
                        .font(.subheadline).lineLimit(1)
                    if let sn = drive.serialNumber {
                        Text(sn).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(drive.mediaType ?? "—").font(.caption).frame(width: 70, alignment: .leading)
            Text(Fmt.gib(drive.capacityBytes)).font(.subheadline.monospacedDigit())
                .frame(width: 90, alignment: .trailing)
            Text(drive.protocol ?? "—").font(.caption).frame(width: 70, alignment: .leading)
            HStack(spacing: 4) {
                HealthBadge(health: drive.status?.effectiveHealth ?? .unknown, compact: true)
                if drive.failurePredicted == true {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            .frame(width: 90, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}
