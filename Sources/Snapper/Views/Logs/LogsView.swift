import SwiftUI

struct LogsView: View {
    let logs: [LogEntry]

    @State private var filter: RedfishHealth?
    @State private var search = ""

    private var filtered: [LogEntry] {
        logs.filter { entry in
            (filter == nil || entry.health == filter) &&
            (search.isEmpty ||
             (entry.message ?? "").localizedCaseInsensitiveContains(search) ||
             (entry.messageID ?? "").localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            if logs.isEmpty {
                EmptySection(icon: "list.bullet.rectangle", text: "No log entries available, or the account lacks log access.")
            } else {
                controls
                Card("System Event Log (\(filtered.count))", systemImage: "list.bullet.rectangle.fill") {
                    ForEach(filtered) { entry in
                        LogRow(entry: entry)
                        Divider()
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            TextField("Search log…", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
            Picker("Severity", selection: $filter) {
                Text("All").tag(RedfishHealth?.none)
                ForEach([RedfishHealth.ok, .warning, .critical], id: \.self) { h in
                    Text(h.label).tag(RedfishHealth?.some(h))
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            Spacer()
            severitySummary
        }
    }

    private var severitySummary: some View {
        HStack(spacing: 10) {
            ForEach([RedfishHealth.critical, .warning, .ok], id: \.self) { h in
                let count = logs.filter { $0.health == h }.count
                if count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: h.symbol).foregroundStyle(h.color)
                        Text("\(count)").font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }
}

private struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.health.symbol)
                .foregroundStyle(entry.health.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message ?? entry.name ?? "—")
                    .font(.subheadline)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    if let id = entry.messageID {
                        Text(id).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                    if let created = entry.created {
                        Text(created).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 5)
    }
}
