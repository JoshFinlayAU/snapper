import SwiftUI

/// Virtual console (KVM) access: embedded WebView window, browser launch, and VNC handoff
/// to macOS Screen Sharing (enabling iDRAC's VNC server via attributes when needed).
struct VirtualConsoleCard: View {
    @ObservedObject var connection: ServerConnection
    @Environment(\.openWindow) private var openWindow

    @State private var vncPort = 5901
    @State private var vncPassword = ""
    @State private var vncSeeded = false

    private var server: SavedServer { connection.server }
    private var attrs: [String: JSONValue] { connection.managerAttributes }

    private var vncSupported: Bool { attrs.keys.contains { $0.hasPrefix("VNCServer.") } }
    private var vncEnabled: Bool { attrs["VNCServer.1.Enable"]?.boolValue ?? false }
    private var currentVNCPort: Int? {
        if case let .int(p)? = attrs["VNCServer.1.Port"] { return p }
        if case let .string(s)? = attrs["VNCServer.1.Port"] { return Int(s) }
        return nil
    }

    var body: some View {
        Card("Virtual Console", systemImage: "display") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Open the iDRAC HTML5 KVM console. You'll sign in to iDRAC inside the console window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        if let url = server.webConsoleURL {
                            openWindow(id: "console", value: ConsoleTarget(
                                id: server.id, name: "\(server.name) — Console",
                                urlString: url.absoluteString, allowSelfSigned: server.allowSelfSigned))
                        }
                    } label: {
                        Label("Open in Snapper", systemImage: "macwindow")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(server.webConsoleURL == nil)

                    Button {
                        if let url = server.webConsoleURL { NSWorkspace.shared.open(url) }
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                    }
                    .disabled(server.webConsoleURL == nil)
                    Spacer()
                }

                Divider()
                vncSection
            }
        }
        .task(id: connection.id) {
            if connection.managerAttributes.isEmpty { await connection.loadManagerAttributes() }
        }
        .onChange(of: currentVNCPort) { _, newValue in
            if let newValue, !vncSeeded { vncPort = newValue; vncSeeded = true }
        }
    }

    @ViewBuilder private var vncSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.connected.to.line.below")
                .foregroundStyle(.secondary)
            Text("VNC (Screen Sharing)").font(.subheadline.weight(.semibold))
            Spacer()
            if vncSupported {
                Text(vncEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(vncEnabled ? .green : .secondary)
            }
        }

        if !vncSupported {
            Text(connection.isLoadingExtras ? "Checking VNC availability…" : "VNC server attributes not exposed (requires a Dell iDRAC with the appropriate license).")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if vncEnabled {
            HStack {
                Text("Connect via macOS Screen Sharing on port \(currentVNCPort ?? vncPort).")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    if let url = server.vncURL(port: currentVNCPort ?? vncPort) { NSWorkspace.shared.open(url) }
                } label: {
                    Label("Open VNC", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
                Button(role: .destructive) {
                    Task { await connection.disableVNC() }
                } label: {
                    Label("Disable", systemImage: "xmark")
                }
            }
            .disabled(connection.actionInFlight)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Port").frame(width: 70, alignment: .leading)
                    TextField("5901", value: $vncPort, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    SecureField("VNC password", text: $vncPassword)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                Button {
                    Task { await connection.enableVNC(port: vncPort, password: vncPassword) }
                } label: {
                    Label("Enable VNC server", systemImage: "play.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(connection.actionInFlight || vncPassword.isEmpty)
                Text("Sets a VNC password and opens the iDRAC VNC port. Use macOS Screen Sharing to connect.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .disabled(connection.actionInFlight)
        }
    }
}
