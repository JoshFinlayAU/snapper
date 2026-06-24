import SwiftUI

/// BIOS attribute browser/editor. Current values come from `/Bios`; the `/Bios/BiosRegistry`
/// drives typed controls (enum dropdowns, integer bounds, toggles) and validation. Edits are
/// staged to the `@Redfish.Settings` object and applied on the next reboot.
struct BiosView: View {
    @ObservedObject var connection: ServerConnection
    let snapshot: RedfishSnapshot

    @State private var search = ""
    @State private var pending: [String: String] = [:]
    @State private var expanded: Set<String> = []

    private var attributes: [String: JSONValue] { connection.biosAttributes }
    private var registry: [String: BiosAttributeDef] { connection.biosRegistry }

    // MARK: derived

    private func current(_ key: String) -> String { attributes[key]?.display ?? "" }

    private var visibleKeys: [String] {
        attributes.keys.filter { registry[$0]?.hidden != true }
    }

    private func matches(_ key: String) -> Bool {
        guard !search.isEmpty else { return true }
        if key.localizedCaseInsensitiveContains(search) { return true }
        if let def = registry[key] {
            if def.label.localizedCaseInsensitiveContains(search) { return true }
            if (def.helpText ?? "").localizedCaseInsensitiveContains(search) { return true }
        }
        return false
    }

    private func sorted(_ keys: [String]) -> [String] {
        keys.sorted { a, b in
            let da = registry[a]?.displayOrder ?? Int.max
            let db = registry[b]?.displayOrder ?? Int.max
            if da != db { return da < db }
            return (registry[a]?.label ?? a).localizedCaseInsensitiveCompare(registry[b]?.label ?? b) == .orderedAscending
        }
    }

    /// Human-readable category name for a raw top-level menu segment. The registry's own
    /// menu display names are unreliable on real iDRACs (they reference child menus), so we
    /// derive the name algorithmically — e.g. "BootSettingsRef" → "Boot Settings".
    private func categoryName(_ raw: String) -> String {
        raw == "Other" ? "Other" : BiosMenuName.pretty(raw)
    }

    private var groups: [(name: String, raw: String, keys: [String])] {
        let filtered = visibleKeys.filter(matches)
        let grouped = Dictionary(grouping: filtered) { registry[$0]?.group ?? "Other" }
        return grouped.map { (name: categoryName($0.key), raw: $0.key, keys: sorted($0.value)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var invalidCount: Int {
        pending.reduce(0) { acc, entry in
            acc + ((registry[entry.key]?.validationError(for: entry.value) != nil) ? 1 : 0)
        }
    }

    // MARK: body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if attributes.isEmpty {
                emptyState
            } else {
                searchField
                if search.isEmpty {
                    groupedList
                } else {
                    flatResults
                }
            }
        }
        .task(id: connection.id) { await connection.loadBios() }
    }

    private var header: some View {
        Card("BIOS Settings", systemImage: "memorychip") {
            VStack(alignment: .leading, spacing: 10) {
                Label(registry.isEmpty
                      ? "Attribute registry unavailable — editing as free text. Changes apply on the next reboot."
                      : "\(registry.count) attributes loaded with types & allowed values. Changes apply on the next host reboot.",
                      systemImage: registry.isEmpty ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(registry.isEmpty ? .orange : .green)

                if !pending.isEmpty {
                    HStack(spacing: 10) {
                        Text("\(pending.count) pending change\(pending.count == 1 ? "" : "s")")
                            .font(.callout.weight(.semibold))
                        if invalidCount > 0 {
                            Text("\(invalidCount) invalid")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        Spacer()
                        Button("Discard") { pending.removeAll() }
                            .buttonStyle(.bordered)
                        Button {
                            apply()
                        } label: {
                            Label("Apply (next reboot)", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(invalidCount > 0)
                    }
                }

                if let message = connection.actionMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search \(visibleKeys.count) attributes…", text: $search)
                .textFieldStyle(.plain)
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cardBackground))
    }

    private var groupedList: some View {
        LazyVStack(spacing: 8) {
            ForEach(groups, id: \.raw) { group in
                DisclosureGroup(isExpanded: expandedBinding(group.raw)) {
                    VStack(spacing: 0) {
                        ForEach(group.keys, id: \.self) { key in
                            row(for: key)
                            Divider()
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack {
                        Text(group.name).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(group.keys.count)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
            }
        }
        .disabled(connection.actionInFlight)
    }

    private var flatResults: some View {
        let keys = sorted(visibleKeys.filter(matches))
        return LazyVStack(spacing: 0) {
            ForEach(keys, id: \.self) { key in
                row(for: key)
                Divider()
            }
            if keys.isEmpty {
                Text("No attributes match “\(search)”.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
        .disabled(connection.actionInFlight)
    }

    private func row(for key: String) -> some View {
        BiosAttributeRow(
            key: key,
            def: registry[key],
            current: current(key),
            text: binding(for: key),
            isChanged: pending[key] != nil
        )
    }

    // MARK: bindings & apply

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { pending[key] ?? current(key) },
            set: { newValue in
                if newValue == current(key) { pending.removeValue(forKey: key) }
                else { pending[key] = newValue }
            }
        )
    }

    private func expandedBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(name) },
            set: { isOn in if isOn { expanded.insert(name) } else { expanded.remove(name) } }
        )
    }

    private func apply() {
        var changes: [String: Any] = [:]
        for (key, text) in pending where registry[key]?.validationError(for: text) == nil {
            changes[key] = registry[key]?.coerced(from: text) ?? text
        }
        guard !changes.isEmpty else { return }
        pending.removeAll()
        Task { await connection.applyBiosChanges(changes) }
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            if connection.isLoadingExtras { ProgressView().controlSize(.small) }
            Text(connection.isLoadingExtras ? "Loading BIOS attributes & registry…" : "No BIOS attributes available for this server.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

// MARK: - Row

private struct BiosAttributeRow: View {
    let key: String
    let def: BiosAttributeDef?
    let current: String
    @Binding var text: String
    let isChanged: Bool

    private var error: String? { def?.validationError(for: text) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(def?.label ?? key)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let help = def?.helpText, !help.isEmpty {
                    Text(help)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if isChanged {
                    Text("was \(current.isEmpty ? "—" : current)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if let error {
                    Text(error).font(.caption2.weight(.semibold)).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control
                .frame(width: 240, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
    }

    private var rowBackground: Color {
        if error != nil { return Color.red.opacity(0.08) }
        if isChanged { return Color.orange.opacity(0.08) }
        return .clear
    }

    @ViewBuilder private var control: some View {
        if def?.readOnly == true {
            Text(current.isEmpty ? "—" : current)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        } else {
            switch def?.kind {
            case .enumeration:
                enumPicker
            case .boolean:
                Toggle("", isOn: boolBinding).labelsHidden()
            case .password:
                SecureField("", text: $text).textFieldStyle(.roundedBorder)
            case .integer:
                VStack(alignment: .trailing, spacing: 1) {
                    TextField("", text: $text).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                    if let lo = def?.lowerBound, let hi = def?.upperBound {
                        Text("\(lo)–\(hi)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            default:
                TextField("", text: $text).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
            }
        }
    }

    private var enumPicker: some View {
        var options = (def?.value ?? []).compactMap { $0.valueName }
        if !text.isEmpty, !options.contains(text) { options.insert(text, at: 0) }
        return Picker("", selection: $text) {
            ForEach(options, id: \.self) { name in
                Text(def?.optionLabel(for: name) ?? name).tag(name)
            }
        }
        .labelsHidden()
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: { (text as NSString).boolValue },
            set: { text = $0 ? "true" : "false" }
        )
    }
}
