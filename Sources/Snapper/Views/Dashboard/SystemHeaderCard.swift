import SwiftUI

/// The hero banner at the top of the dashboard: server identity + overall health.
struct SystemHeaderCard: View {
    let snapshot: RedfishSnapshot

    private var system: ComputerSystem? { snapshot.system }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(system?.model ?? snapshot.chassis?.model ?? "Unknown System")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 10) {
                    if let mfr = system?.manufacturer {
                        labelChip(icon: "building.2", text: mfr)
                    }
                    if let serial = system?.serialNumber {
                        labelChip(icon: "number", text: serial)
                    }
                    if let bios = system?.biosVersion {
                        labelChip(icon: "cpu", text: "BIOS \(bios)")
                    }
                }
                if let host = system?.hostName {
                    Text(host)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: snapshot.overallHealth.symbol)
                    .font(.system(size: 38))
                    .foregroundStyle(.white)
                Text(snapshot.overallHealth.label)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Overall Health")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 8)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Theme.headerGradient
                healthOverlay
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.3), radius: 12, x: 0, y: 5)
    }

    private var healthOverlay: some View {
        let tint: Color
        switch snapshot.overallHealth {
        case .critical: tint = .red
        case .warning: tint = .orange
        default: tint = .clear
        }
        return tint.opacity(0.35)
    }

    private func labelChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text).lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(0.18)))
    }
}
