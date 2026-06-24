import SwiftUI

/// Horizontal strip of open server connections, each a closable tab.
struct ConnectionTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.connections) { conn in
                    TabChip(connection: conn,
                            isSelected: conn.id == appState.selectedConnectionID)
                        .onTapGesture { appState.selectedConnectionID = conn.id }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

private struct TabChip: View {
    @ObservedObject var connection: ServerConnection
    @EnvironmentObject var appState: AppState
    let isSelected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            statusIndicator
            Text(connection.title)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
            Button {
                appState.closeConnection(connection)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.borderless)
            .opacity(hovering || isSelected ? 1 : 0.0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.18) : Color.primary.opacity(hovering ? 0.07 : 0.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1)
        )
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var statusIndicator: some View {
        switch connection.phase {
        case .connecting:
            ProgressView().controlSize(.small).scaleEffect(0.7)
        case .connected:
            StatusDot(health: connection.snapshot?.overallHealth ?? .unknown)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        case .idle:
            Circle().fill(.gray).frame(width: 9, height: 9)
        }
    }
}
