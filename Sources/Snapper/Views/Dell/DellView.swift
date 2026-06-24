import SwiftUI

/// A Dell iDRAC 9-specific template highlighting the BMC and Dell service identifiers.
struct DellView: View {
    @ObservedObject var connection: ServerConnection
    let snapshot: RedfishSnapshot

    private var manager: Manager? { snapshot.manager }
    private var system: ComputerSystem? { snapshot.system }

    var body: some View {
        VStack(spacing: 18) {
            banner
            idracCard
            serviceCard
            NetworkConfigCard(connection: connection)
            SNMPConfigCard(connection: connection)
            LocationConfigCard(connection: connection)
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

// MARK: - SNMP configuration

/// Editable iDRAC SNMP settings, backed by the `Managers/{id}/Attributes` resource.
/// Curated SNMP.* / SNMPAlert.* attributes are surfaced as proper controls; edits are
/// staged locally and applied together.
private struct SNMPConfigCard: View {
    @ObservedObject var connection: ServerConnection
    @State private var pending: [String: Any] = [:]

    private var attrs: [String: JSONValue] { connection.managerAttributes }
    private var hasSNMP: Bool { attrs.keys.contains { $0.hasPrefix("SNMP") } }

    /// Trap destination indices present (from SNMPAlert.<n>.Destination keys), sorted.
    private var trapIndices: [Int] {
        let nums = attrs.keys.compactMap { key -> Int? in
            guard key.hasPrefix("SNMPAlert."), key.hasSuffix(".Destination") else { return nil }
            return Int(key.dropFirst("SNMPAlert.".count).prefix { $0 != "." })
        }
        return Array(Set(nums)).sorted()
    }

    var body: some View {
        Card("SNMP", systemImage: "antenna.radiowaves.left.and.right") {
            if connection.managerAttributes.isEmpty {
                HStack(spacing: 8) {
                    if connection.isLoadingExtras { ProgressView().controlSize(.small) }
                    Text(connection.isLoadingExtras ? "Loading SNMP settings…" : "SNMP settings unavailable.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if !hasSNMP {
                Text("This controller exposes no SNMP attributes.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                content
            }
        }
        .disabled(connection.actionInFlight)
        .task(id: connection.id) { await connection.loadManagerAttributes() }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if present("SNMP.1.AgentEnable") {
                Toggle("SNMP Agent enabled", isOn: boolBinding("SNMP.1.AgentEnable"))
            }
            if present("SNMP.1.AgentCommunity") {
                labeledField("Community string", key: "SNMP.1.AgentCommunity")
            }
            if present("SNMP.1.SNMPProtocol") {
                labeledPicker("Protocol", key: "SNMP.1.SNMPProtocol", options: ["All", "SNMPv3"])
            }
            if present("SNMP.1.TrapFormat") {
                labeledPicker("Trap format", key: "SNMP.1.TrapFormat", options: ["SNMPv1", "SNMPv2", "SNMPv3"])
            }
            HStack {
                if present("SNMP.1.AlertPort") { labeledField("Alert port", key: "SNMP.1.AlertPort", width: 90) }
                if present("SNMP.1.DiscoveryPort") { labeledField("Agent port", key: "SNMP.1.DiscoveryPort", width: 90) }
                Spacer()
            }

            if !trapIndices.isEmpty {
                Divider()
                Text("Trap Destinations").font(.subheadline.weight(.semibold))
                ForEach(trapIndices, id: \.self) { idx in
                    HStack(spacing: 8) {
                        let stateKey = "SNMPAlert.\(idx).State"
                        if present(stateKey) {
                            Toggle("", isOn: boolBinding(stateKey)).labelsHidden()
                        }
                        TextField("Destination \(idx)", text: stringBinding("SNMPAlert.\(idx).Destination"))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack {
                Button {
                    apply()
                } label: {
                    Label("Apply SNMP settings", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(pending.isEmpty)

                if !pending.isEmpty {
                    Text("\(pending.count) change\(pending.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: helpers

    private func present(_ key: String) -> Bool { attrs[key] != nil }

    private func labeledField(_ label: String, key: String, width: CGFloat? = nil) -> some View {
        HStack {
            Text(label).frame(width: 130, alignment: .leading)
            TextField(label, text: stringBinding(key))
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
        }
    }

    private func labeledPicker(_ label: String, key: String, options: [String]) -> some View {
        HStack {
            Text(label).frame(width: 130, alignment: .leading)
            Picker(label, selection: stringBinding(key)) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 160)
            Spacer()
        }
    }

    private func currentString(_ key: String) -> String {
        (pending[key] as? String) ?? attrs[key]?.display ?? ""
    }

    private func stringBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { currentString(key) },
            set: { newValue in
                if newValue == (attrs[key]?.display ?? "") { pending.removeValue(forKey: key) }
                else { pending[key] = attrs[key]?.coerced(from: newValue) ?? newValue }
            }
        )
    }

    /// Dell SNMP enable/state attributes are "Enabled"/"Disabled" strings.
    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: {
                if let pendingVal = pending[key] as? String { return pendingVal == "Enabled" }
                return attrs[key]?.boolValue ?? false
            },
            set: { isOn in
                let newValue = isOn ? "Enabled" : "Disabled"
                if newValue == attrs[key]?.display { pending.removeValue(forKey: key) }
                else { pending[key] = newValue }
            }
        )
    }

    private func apply() {
        let changes = pending
        let count = changes.count
        pending.removeAll()
        Task { await connection.applyManagerChanges(changes, summary: "Applied \(count) SNMP setting\(count == 1 ? "" : "s").") }
    }
}

// MARK: - Physical location (drives the location iDRAC reports over SNMP)

/// Editable server physical-location fields from the iDRAC `ServerTopology` attribute group —
/// this is the location iDRAC surfaces via SNMP (there is no separate SNMP location string).
private struct LocationConfigCard: View {
    @ObservedObject var connection: ServerConnection
    @State private var pending: [String: Any] = [:]

    private var attrs: [String: JSONValue] { connection.managerAttributes }
    private var hasTopology: Bool { attrs.keys.contains { $0.hasPrefix("ServerTopology.") } }

    private let fields: [(key: String, label: String)] = [
        ("ServerTopology.1.DataCenterName", "Data Center"),
        ("ServerTopology.1.RoomName", "Room"),
        ("ServerTopology.1.AisleName", "Aisle"),
        ("ServerTopology.1.RackName", "Rack"),
        ("ServerTopology.1.RackSlot", "Rack Slot"),
        ("ServerTopology.1.SizeOfManagedSystemInU", "Size (U)")
    ]

    var body: some View {
        Card("Physical Location", systemImage: "mappin.and.ellipse") {
            if connection.managerAttributes.isEmpty {
                HStack(spacing: 8) {
                    if connection.isLoadingExtras { ProgressView().controlSize(.small) }
                    Text(connection.isLoadingExtras ? "Loading location…" : "Location settings unavailable.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if !hasTopology {
                Text("This controller exposes no ServerTopology location attributes.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                content
            }
        }
        .disabled(connection.actionInFlight)
        .task(id: connection.id) {
            if connection.managerAttributes.isEmpty { await connection.loadManagerAttributes() }
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This is the location iDRAC reports over SNMP.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(fields.filter { attrs[$0.key] != nil }, id: \.key) { field in
                HStack {
                    Text(field.label).frame(width: 110, alignment: .leading)
                    TextField(field.label, text: stringBinding(field.key))
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                Button { apply() } label: {
                    Label("Apply location", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(pending.isEmpty)
                if !pending.isEmpty {
                    Text("\(pending.count) change\(pending.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func stringBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { (pending[key] as? String) ?? attrs[key]?.display ?? "" },
            set: { newValue in
                if newValue == (attrs[key]?.display ?? "") { pending.removeValue(forKey: key) }
                else { pending[key] = attrs[key]?.coerced(from: newValue) ?? newValue }
            }
        )
    }

    private func apply() {
        let changes = pending
        let count = changes.count
        pending.removeAll()
        Task { await connection.applyManagerChanges(changes, summary: "Updated \(count) location field\(count == 1 ? "" : "s").") }
    }
}
