import SwiftUI

struct StorageView: View {
    @ObservedObject var connection: ServerConnection
    let snapshot: RedfishSnapshot

    @State private var volumePendingDelete: Volume?
    @State private var creatingOn: StorageSubsystem?

    var body: some View {
        VStack(spacing: 18) {
            if snapshot.storage.isEmpty && snapshot.drives.isEmpty {
                EmptySection(icon: "internaldrive", text: "No storage subsystems reported by this server.")
            } else {
                if let message = connection.actionMessage {
                    Label(message, systemImage: connection.actionInFlight ? "hourglass" : "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(connection.actionInFlight ? Color.secondary : Color.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
                }

                ForEach(snapshot.storage) { sub in
                    controllerCard(sub)
                    virtualDisksCard(sub)
                }
                if !snapshot.drives.isEmpty { drivesCard }
            }
        }
        .disabled(connection.actionInFlight)
        .alert(item: $volumePendingDelete) { volume in
            Alert(
                title: Text("Delete \(volume.title)?"),
                message: Text("This permanently destroys the virtual disk and all data on it. A configuration job will be queued."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await connection.deleteVolume(volume) }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(item: $creatingOn) { sub in
            CreateVolumeSheet(connection: connection,
                              subsystem: sub,
                              drives: drives(for: sub))
        }
    }

    private func drives(for sub: StorageSubsystem) -> [Drive] {
        let matched = snapshot.drives.filter { ($0.idField ?? "").contains(sub.idField ?? "\u{0}") }
        return matched.isEmpty ? snapshot.drives : matched
    }

    private func volumes(for sub: StorageSubsystem) -> [Volume] {
        snapshot.volumes.filter { ($0.odataID ?? "").contains(sub.idField ?? "\u{0}") }
    }

    // MARK: - Controller

    private func controllerCard(_ sub: StorageSubsystem) -> some View {
        Card(sub.name ?? "Storage Controller", systemImage: "externaldrive.connected.to.line.below.fill") {
            ForEach(Array((sub.storageControllers ?? []).enumerated()), id: \.offset) { _, ctrl in
                VStack(alignment: .leading, spacing: 6) {
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
                    }
                    HStack(spacing: 14) {
                        if let raid = ctrl.supportedRAIDTypes, !raid.isEmpty {
                            metric("RAID", raid.joined(separator: ", "))
                        }
                        if let cache = ctrl.cacheSummary?.totalCacheSizeMiB, cache > 0 {
                            metric("Cache", "\(Int(cache)) MiB")
                        }
                        if let proto = ctrl.supportedDeviceProtocols, !proto.isEmpty {
                            metric("Bus", proto.joined(separator: ", "))
                        }
                        if let speed = ctrl.speedGbps {
                            metric("Speed", "\(Int(speed)) Gb/s")
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.medium))
        }
    }

    // MARK: - Virtual disks

    @ViewBuilder private func virtualDisksCard(_ sub: StorageSubsystem) -> some View {
        let allVols = volumes(for: sub)
        let vds = allVols.filter { $0.isVirtualDisk }
        let nonRaidCount = allVols.count - vds.count
        let canCreate = sub.isRAID && sub.volumesPath != nil
        if sub.isRAID || !vds.isEmpty {
            Card("Virtual Disks (\(vds.count))", systemImage: "rectangle.stack.fill") {
                if vds.isEmpty {
                    Text("No RAID virtual disks on this controller.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if nonRaidCount > 0 {
                    Label("\(nonRaidCount) disk\(nonRaidCount == 1 ? "" : "s") in Non-RAID (passthrough) mode — convert a disk to RAID (in the drive menu below) before adding it to a virtual disk.",
                          systemImage: "info.circle")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(vds) { volume in
                    HStack(spacing: 10) {
                        StatusDot(health: volume.status?.effectiveHealth ?? .unknown)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(volume.title).font(.subheadline.weight(.medium))
                            Text("\(volume.raidType ?? volume.volumeType ?? "—") · \(volume.driveCount) drives\(volume.encrypted == true ? " · encrypted" : "")")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.gib(volume.capacityBytes)).font(.subheadline.monospacedDigit())
                        Button(role: .destructive) {
                            volumePendingDelete = volume
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Delete virtual disk")
                    }
                    .padding(.vertical, 3)
                    Divider()
                }
                if canCreate {
                    Button {
                        creatingOn = sub
                    } label: {
                        Label("Create Virtual Disk", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Physical drives

    private var drivesCard: some View {
        Card("Physical Drives (\(snapshot.drives.count))", systemImage: "internaldrive.fill") {
            DriveTable(connection: connection, drives: snapshot.drives)
        }
    }
}

private struct DriveTable: View {
    @ObservedObject var connection: ServerConnection
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
            Text("Media").frame(width: 64, alignment: .leading)
            Text("Capacity").frame(width: 84, alignment: .trailing)
            Text("Bus").frame(width: 56, alignment: .leading)
            Text("Health").frame(width: 80, alignment: .leading)
            Text("Locate").frame(width: 60, alignment: .center)
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

            Text(drive.mediaType ?? "—").font(.caption).frame(width: 64, alignment: .leading)
            Text(Fmt.gib(drive.capacityBytes)).font(.subheadline.monospacedDigit())
                .frame(width: 84, alignment: .trailing)
            Text(drive.protocol ?? "—").font(.caption).frame(width: 56, alignment: .leading)
            HStack(spacing: 4) {
                HealthBadge(health: drive.status?.effectiveHealth ?? .unknown, compact: true)
                if drive.failurePredicted == true {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            .frame(width: 80, alignment: .leading)

            Menu {
                Button { Task { await connection.locateDrive(drive, on: true) } } label: {
                    Label("Blink locate LED", systemImage: "lightbulb.fill")
                }
                Button { Task { await connection.locateDrive(drive, on: false) } } label: {
                    Label("Stop blinking", systemImage: "lightbulb.slash")
                }
                Divider()
                Button { Task { await connection.convertDrive(drive, toRAID: true) } } label: {
                    Label("Convert to RAID", systemImage: "square.stack.3d.up")
                }
                Button { Task { await connection.convertDrive(drive, toRAID: false) } } label: {
                    Label("Convert to Non-RAID", systemImage: "square.stack.3d.up.slash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 60, alignment: .center)
            .disabled(drive.fqdd == nil)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Create Virtual Disk sheet

private struct CreateVolumeSheet: View {
    @ObservedObject var connection: ServerConnection
    let subsystem: StorageSubsystem
    let drives: [Drive]
    @Environment(\.dismiss) private var dismiss

    @State private var raidType = ""
    @State private var name = ""
    @State private var selected: Set<String> = []

    private var raidTypes: [String] { subsystem.raidController?.supportedRAIDTypes ?? ["RAID0", "RAID1", "RAID5", "RAID6", "RAID10"] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "plus.rectangle.on.folder.fill").foregroundStyle(Theme.accent)
                Text("Create Virtual Disk").font(.title3.weight(.semibold))
                Spacer()
            }
            .padding()
            Divider()

            Form {
                Section {
                    TextField("Name (optional)", text: $name, prompt: Text("e.g. VD0"))
                    Picker("RAID level", selection: $raidType) {
                        ForEach(raidTypes, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Physical disks (\(selected.count) selected)") {
                    ForEach(drives) { drive in
                        Toggle(isOn: binding(for: drive)) {
                            HStack {
                                Image(systemName: drive.isSSD ? "memorychip" : "internaldrive")
                                Text(drive.model ?? drive.name ?? "Drive").lineLimit(1)
                                Spacer()
                                Text(Fmt.gib(drive.capacityBytes)).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(drive.odataID == nil)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Text("\(raidType.isEmpty ? "Select a RAID level" : raidType) · \(selected.count) disks")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create") {
                    Task {
                        await connection.createVolume(
                            volumesPath: subsystem.volumesPath ?? "",
                            raidType: raidType,
                            name: name.trimmingCharacters(in: .whitespaces),
                            driveODataIDs: drives.filter { selected.contains($0.id) }.compactMap { $0.odataID })
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(raidType.isEmpty || selected.count < 1)
            }
            .padding()
        }
        .frame(width: 480, height: 520)
        .onAppear { if raidType.isEmpty { raidType = raidTypes.first ?? "" } }
    }

    private func binding(for drive: Drive) -> Binding<Bool> {
        Binding(
            get: { selected.contains(drive.id) },
            set: { on in if on { selected.insert(drive.id) } else { selected.remove(drive.id) } }
        )
    }
}
