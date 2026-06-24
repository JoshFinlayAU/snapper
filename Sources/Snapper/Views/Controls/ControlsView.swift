import SwiftUI

/// Writable server controls ("knobs"): identify LED, boot override, asset tag, power cap.
struct ControlsView: View {
    @ObservedObject var connection: ServerConnection
    let snapshot: RedfishSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let message = connection.actionMessage {
                Label(message, systemImage: connection.actionInFlight ? "hourglass" : "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(connection.actionInFlight ? Color.secondary : Color.green)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }

            if snapshot.manager != nil {
                VirtualConsoleCard(connection: connection)
                VirtualMediaCard(connection: connection)
            }

            if let system = snapshot.system {
                IdentifyCard(connection: connection, system: system)
                BootOverrideCard(connection: connection, system: system)
                AssetTagCard(connection: connection, system: system)
            }

            if let control = snapshot.power?.powerControl?.first, snapshot.chassis?.power != nil {
                PowerCapCard(connection: connection, control: control)
            }
        }
        .disabled(connection.actionInFlight)
        .task(id: connection.id) { await connection.loadVirtualMedia() }
    }
}

// MARK: - Virtual media

private struct VirtualMediaCard: View {
    @ObservedObject var connection: ServerConnection

    var body: some View {
        Card("Virtual Media", systemImage: "opticaldiscdrive.fill") {
            if connection.virtualMedia.isEmpty {
                HStack(spacing: 8) {
                    if connection.isLoadingExtras { ProgressView().controlSize(.small) }
                    Text(connection.isLoadingExtras ? "Loading virtual media…" : "No virtual media devices reported.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(connection.virtualMedia) { device in
                        VirtualMediaDeviceRow(connection: connection, device: device)
                        if device.id != connection.virtualMedia.last?.id { Divider() }
                    }
                }
            }
        }
    }
}

private struct VirtualMediaDeviceRow: View {
    @ObservedObject var connection: ServerConnection
    let device: VirtualMediaDevice

    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showCredentials = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: device.isInserted ? "opticaldiscdrive.fill" : "opticaldiscdrive")
                    .foregroundStyle(device.isInserted ? Theme.accent : .secondary)
                Text(device.kind).font(.subheadline.weight(.medium))
                Spacer()
                if device.isInserted {
                    Text("Mounted").font(.caption).foregroundStyle(.green)
                }
            }

            if device.isInserted {
                Text(device.image ?? device.imageName ?? "Unknown image")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Button(role: .destructive) {
                    Task { await connection.ejectMedia(device) }
                } label: {
                    Label("Eject", systemImage: "eject.fill")
                }
                .buttonStyle(.bordered)
            } else {
                TextField("Image URL", text: $url,
                          prompt: Text("https://host/path/image.iso  or  //host/share/image.iso"))
                    .textFieldStyle(.roundedBorder)
                if showCredentials {
                    HStack {
                        TextField("Username (CIFS)", text: $username).textFieldStyle(.roundedBorder)
                        SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
                    }
                }
                HStack {
                    Button {
                        Task { await connection.mountMedia(device, image: url.trimmingCharacters(in: .whitespaces),
                                                           username: username, password: password) }
                    } label: {
                        Label("Mount", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)

                    Toggle("CIFS credentials", isOn: $showCredentials)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Identify LED

private struct IdentifyCard: View {
    @ObservedObject var connection: ServerConnection
    let system: ComputerSystem

    var body: some View {
        Card("Identify / Locate", systemImage: "lightbulb.fill") {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(system.isIdentifyActive ? Color.blue : Color.secondary.opacity(0.25))
                        .frame(width: 44, height: 44)
                        .shadow(color: system.isIdentifyActive ? .blue.opacity(0.7) : .clear, radius: 10)
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(system.isIdentifyActive ? .white : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(system.isIdentifyActive ? "Blinking" : "Off")
                        .font(.headline)
                    Text("Flash the chassis ID LED to find this server in the rack.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { system.isIdentifyActive },
                    set: { on in Task { await connection.setIdentify(on) } }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
    }
}

// MARK: - Boot override

private struct BootOverrideCard: View {
    @ObservedObject var connection: ServerConnection
    let system: ComputerSystem

    @State private var target: String = ""
    @State private var persistent = false

    private var allowable: [String] {
        let values = system.boot?.allowableTargets?.filter { $0 != "None" }
        return values?.isEmpty == false ? values! : ["Pxe", "Hdd", "Cd", "Usb", "BiosSetup", "Utilities"]
    }

    var body: some View {
        Card("Next Boot", systemImage: "arrow.right.circle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                currentStatus

                HStack(spacing: 12) {
                    Picker("Boot to", selection: $target) {
                        ForEach(allowable, id: \.self) { value in
                            Text(Self.friendly(value)).tag(value)
                        }
                    }
                    .frame(maxWidth: 260)

                    Toggle("Every boot", isOn: $persistent)
                        .toggleStyle(.checkbox)
                        .help("On: applies to every boot (Continuous). Off: one time only (Once).")
                }

                HStack {
                    Button {
                        Task { await connection.setBootOverride(target: target, persistent: persistent) }
                    } label: {
                        Label("Apply", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(target.isEmpty)

                    if system.boot?.isOverrideActive == true {
                        Button(role: .destructive) {
                            Task { await connection.setBootOverride(target: nil, persistent: false) }
                        } label: {
                            Label("Clear override", systemImage: "xmark")
                        }
                    }
                }
            }
        }
        .onAppear {
            if target.isEmpty { target = system.boot?.bootSourceOverrideTarget.flatMap { allowable.contains($0) ? $0 : nil } ?? allowable.first ?? "" }
            persistent = system.boot?.bootSourceOverrideEnabled == "Continuous"
        }
    }

    @ViewBuilder private var currentStatus: some View {
        if let boot = system.boot, boot.isOverrideActive, let t = boot.bootSourceOverrideTarget {
            Label("Currently overriding next boot to \(Self.friendly(t)) (\(boot.bootSourceOverrideEnabled ?? "Once")).",
                  systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Text("No override set — server boots from its normal boot order.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    static func friendly(_ value: String) -> String {
        switch value {
        case "Pxe": return "PXE Network"
        case "Hdd": return "Hard Drive"
        case "Cd": return "CD / DVD"
        case "Usb": return "USB"
        case "BiosSetup": return "BIOS Setup"
        case "Utilities": return "Utilities"
        case "UefiTarget": return "UEFI Target"
        case "SDCard": return "SD Card"
        case "UefiHttp": return "UEFI HTTP"
        case "Diags": return "Diagnostics"
        case "Floppy": return "Floppy"
        default: return value
        }
    }
}

// MARK: - Asset tag

private struct AssetTagCard: View {
    @ObservedObject var connection: ServerConnection
    let system: ComputerSystem

    @State private var tag: String = ""
    @State private var seeded = false

    private var current: String { system.assetTag ?? "" }

    var body: some View {
        Card("Asset Tag", systemImage: "tag.fill") {
            HStack(spacing: 12) {
                TextField("Asset tag", text: $tag, prompt: Text("e.g. ACME-DC1-R12"))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                Button {
                    Task { await connection.setAssetTag(tag.trimmingCharacters(in: .whitespaces)) }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(tag.trimmingCharacters(in: .whitespaces) == current)
                Spacer()
            }
        }
        .onAppear {
            if !seeded { tag = current; seeded = true }
        }
    }
}

// MARK: - Power cap

private struct PowerCapCard: View {
    @ObservedObject var connection: ServerConnection
    let control: Power.PowerControl

    @State private var enabled = false
    @State private var watts: Double = 0
    @State private var seeded = false

    private var capacity: Double { control.powerCapacityWatts ?? 1000 }
    private var minWatts: Double { max(100, (capacity * 0.2).rounded()) }
    private var currentLimit: Double? { control.powerLimit?.limitInWatts }

    var body: some View {
        Card("Power Cap", systemImage: "gauge.with.dots.needle.bottom.50percent") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Limit chassis power draw")
                        .font(.callout)
                    Spacer()
                    Toggle("", isOn: $enabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if enabled {
                    HStack {
                        Slider(value: $watts, in: minWatts...capacity, step: 10)
                        Text("\(Int(watts)) W")
                            .font(.headline.monospacedDigit())
                            .frame(width: 72, alignment: .trailing)
                    }
                    Text("Cap range \(Int(minWatts))–\(Int(capacity)) W (chassis capacity \(Int(capacity)) W).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        Task { await connection.setPowerLimit(enabled ? Int(watts) : nil) }
                    } label: {
                        Label("Apply", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            guard !seeded else { return }
            if let limit = currentLimit {
                enabled = true
                watts = min(max(limit, minWatts), capacity)
            } else {
                enabled = false
                watts = (capacity * 0.8).rounded()
            }
            seeded = true
        }
    }

    private var statusText: String {
        if let limit = currentLimit {
            return "Currently capped at \(Int(limit)) W."
        }
        return "Currently uncapped."
    }
}
