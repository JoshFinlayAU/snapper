import SwiftUI

/// iDRAC network configuration (NIC, hostname/DNS, IPv4, VLAN) and LLDP / switch-connection,
/// backed by the iDRAC `Managers/{id}/Attributes` resource. When the static IP is changed,
/// offers to update the saved server entry and reconnect to the new address.
struct NetworkConfigCard: View {
    @ObservedObject var connection: ServerConnection
    @EnvironmentObject var appState: AppState
    @State private var pending: [String: Any] = [:]

    private var attrs: [String: JSONValue] { connection.managerAttributes }
    private var hasNetwork: Bool { attrs.keys.contains { $0.hasPrefix("IPv4.") || $0.hasPrefix("NIC.1.") } }
    private var usesDHCP: Bool { effective("IPv4.1.DHCPEnable") == "Enabled" }

    var body: some View {
        Card("iDRAC Network & LLDP", systemImage: "network.badge.shield.half.filled") {
            if connection.managerAttributes.isEmpty {
                HStack(spacing: 8) {
                    if connection.isLoadingExtras { ProgressView().controlSize(.small) }
                    Text(connection.isLoadingExtras ? "Loading network settings…" : "Network settings unavailable.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if !hasNetwork {
                Text("This controller exposes no iDRAC network attributes.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                content
            }
        }
        .disabled(connection.actionInFlight)
        .task(id: connection.id) {
            if connection.managerAttributes.isEmpty { await connection.loadManagerAttributes() }
        }
        .alert("Update saved server?", isPresented: Binding(
            get: { connection.suggestedIPUpdate != nil },
            set: { if !$0 { connection.suggestedIPUpdate = nil } }
        )) {
            Button("Keep \(connection.server.bareHost)", role: .cancel) { connection.suggestedIPUpdate = nil }
            Button("Update & reconnect") {
                if let ip = connection.suggestedIPUpdate {
                    appState.updateHost(for: connection, to: ip)
                }
                connection.suggestedIPUpdate = nil
            }
        } message: {
            Text("The iDRAC's static IP is changing to \(connection.suggestedIPUpdate ?? ""). Update the saved server “\(connection.server.name)” to use the new address and reconnect? (The iDRAC may take a moment to come back.)")
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            // LLDP / switch connection
            if present("SwitchConnectionView.1.Enable") {
                Toggle("LLDP switch-connection view", isOn: boolBinding("SwitchConnectionView.1.Enable"))
                    .help("Shows which switch and port the iDRAC NIC is connected to, via LLDP.")
                Divider()
            }

            // Connection
            sectionTitle("Connection")
            if present("NIC.1.Selection") {
                labeledPicker("NIC", key: "NIC.1.Selection", options: ["Dedicated", "LOM1", "LOM2", "LOM3", "LOM4"])
            }
            if present("NIC.1.Autoneg") {
                Toggle("Auto-negotiation", isOn: boolBinding("NIC.1.Autoneg"))
            }
            HStack {
                if present("NIC.1.Speed") { labeledPicker("Speed", key: "NIC.1.Speed", options: ["10", "100", "1000"], width: 110) }
                if present("NIC.1.Duplex") { labeledPicker("Duplex", key: "NIC.1.Duplex", options: ["Full", "Half"], width: 110) }
            }
            if present("NIC.1.MTU") { labeledField("MTU", key: "NIC.1.MTU", width: 90) }

            // Hostname / DNS
            Divider(); sectionTitle("Hostname & DNS")
            if present("NIC.1.DNSRacName") { labeledField("Hostname", key: "NIC.1.DNSRacName") }
            if present("NIC.1.DNSDomainName") { labeledField("Domain", key: "NIC.1.DNSDomainName") }

            // IPv4
            Divider(); sectionTitle("IPv4")
            if present("IPv4.1.DHCPEnable") {
                Toggle("Obtain IP automatically (DHCP)", isOn: boolBinding("IPv4.1.DHCPEnable"))
            }
            if usesDHCP {
                Text("Current: \(attrs["IPv4.1.Address"]?.display ?? "—") / \(attrs["IPv4.1.Netmask"]?.display ?? "—"), gw \(attrs["IPv4.1.Gateway"]?.display ?? "—")")
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
            } else {
                if present("IPv4Static.1.Address") { labeledField("IP address", key: "IPv4Static.1.Address") }
                if present("IPv4Static.1.Netmask") { labeledField("Subnet mask", key: "IPv4Static.1.Netmask") }
                if present("IPv4Static.1.Gateway") { labeledField("Gateway", key: "IPv4Static.1.Gateway") }
                HStack {
                    if present("IPv4Static.1.DNS1") { labeledField("DNS 1", key: "IPv4Static.1.DNS1", width: 150) }
                    if present("IPv4Static.1.DNS2") { labeledField("DNS 2", key: "IPv4Static.1.DNS2", width: 150) }
                }
            }

            // VLAN
            if present("NIC.1.VLanEnable") {
                Divider(); sectionTitle("VLAN")
                Toggle("VLAN enabled", isOn: boolBinding("NIC.1.VLanEnable"))
                if effective("NIC.1.VLanEnable") == "Enabled", present("NIC.1.VLanID") {
                    labeledField("VLAN ID", key: "NIC.1.VLanID", width: 90)
                }
            }

            // Apply
            HStack {
                Button { apply() } label: {
                    Label("Apply network settings", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(pending.isEmpty)
                if !pending.isEmpty {
                    Text("\(pending.count) change\(pending.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if pending.keys.contains(where: { $0.hasPrefix("IPv4") }) && !usesDHCP {
                Label("Changing the IP address will move the iDRAC — you'll be offered to update this server entry after applying.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    // MARK: helpers

    private func present(_ key: String) -> Bool { attrs[key] != nil }
    private func sectionTitle(_ t: String) -> some View { Text(t).font(.subheadline.weight(.semibold)) }
    private func effective(_ key: String) -> String { (pending[key] as? String) ?? attrs[key]?.display ?? "" }

    private func labeledField(_ label: String, key: String, width: CGFloat? = nil) -> some View {
        HStack {
            Text(label).frame(width: 130, alignment: .leading)
            TextField(label, text: stringBinding(key)).textFieldStyle(.roundedBorder).frame(width: width)
        }
    }

    private func labeledPicker(_ label: String, key: String, options: [String], width: CGFloat = 160) -> some View {
        HStack {
            Text(label).frame(width: 130, alignment: .leading)
            Picker(label, selection: stringBinding(key)) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden().frame(width: width)
            Spacer()
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

    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: {
                if let p = pending[key] as? String { return p == "Enabled" }
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
        let newIP = (changes["IPv4Static.1.Address"] as? String).flatMap { usesDHCP ? nil : $0 }
        pending.removeAll()
        Task { await connection.applyNetworkChanges(changes, newStaticIP: newIP) }
    }
}
