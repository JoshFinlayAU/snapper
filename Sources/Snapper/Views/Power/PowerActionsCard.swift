import SwiftUI

/// Power-control buttons backed by the ComputerSystem.Reset action.
struct PowerActionsCard: View {
    @ObservedObject var connection: ServerConnection
    let snapshot: RedfishSnapshot
    @State private var pendingAction: PowerAction?

    struct PowerAction: Identifiable {
        let id = UUID()
        let resetType: String
        let title: String
        let icon: String
        let tint: Color
        let destructive: Bool
    }

    private var allowable: [String] {
        snapshot.system?.actions?.reset?.allowableValues
            ?? ["On", "GracefulShutdown", "ForceRestart", "GracefulRestart", "ForceOff"]
    }

    private var actions: [PowerAction] {
        let catalog: [PowerAction] = [
            .init(resetType: "On", title: "Power On", icon: "power", tint: .green, destructive: false),
            .init(resetType: "GracefulShutdown", title: "Graceful Shutdown", icon: "moon.fill", tint: .orange, destructive: true),
            .init(resetType: "GracefulRestart", title: "Graceful Restart", icon: "arrow.clockwise", tint: .blue, destructive: true),
            .init(resetType: "ForceRestart", title: "Force Restart", icon: "bolt.circle", tint: .orange, destructive: true),
            .init(resetType: "ForceOff", title: "Force Off", icon: "poweroff", tint: .red, destructive: true),
            .init(resetType: "Nmi", title: "Send NMI", icon: "exclamationmark.triangle", tint: .red, destructive: true)
        ]
        return catalog.filter { allowable.contains($0.resetType) }
    }

    var body: some View {
        Card("Power Control", systemImage: "power.circle.fill") {
            if let message = connection.actionMessage {
                Label(message, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            FlowButtons(actions: actions, disabled: connection.actionInFlight) { action in
                if action.destructive {
                    pendingAction = action
                } else {
                    Task { await connection.performReset(action.resetType) }
                }
            }
            if connection.actionInFlight {
                ProgressView().controlSize(.small)
            }
        }
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text("\(action.title)?"),
                message: Text("This will \(action.title.lowercased()) the server. Confirm to proceed."),
                primaryButton: .destructive(Text(action.title)) {
                    Task { await connection.performReset(action.resetType) }
                },
                secondaryButton: .cancel()
            )
        }
    }
}

private struct FlowButtons: View {
    let actions: [PowerActionsCard.PowerAction]
    let disabled: Bool
    let onTap: (PowerActionsCard.PowerAction) -> Void

    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(actions) { action in
                Button {
                    onTap(action)
                } label: {
                    Label(action.title, systemImage: action.icon)
                        .frame(maxWidth: .infinity)
                }
                .tint(action.tint)
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .disabled(disabled)
    }
}
