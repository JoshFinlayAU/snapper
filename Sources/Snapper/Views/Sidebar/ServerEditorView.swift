import SwiftUI

/// Sheet for adding or editing a saved server, including its credentials.
struct ServerEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let server: SavedServer?

    @State private var name = ""
    @State private var host = ""
    @State private var portText = ""
    @State private var username = "root"
    @State private var password = ""
    @State private var allowSelfSigned = true

    private var isEditing: Bool { server != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .frame(width: 460)
        .onAppear(perform: populate)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            Text(isEditing ? "Edit Server" : "Add Server")
                .font(.title3.weight(.semibold))
            Spacer()
        }
        .padding()
    }

    private var form: some View {
        Form {
            Section {
                TextField("Display name", text: $name, prompt: Text("Production iDRAC"))
                TextField("Host / IP", text: $host, prompt: Text("10.0.0.5"))
                TextField("Port", text: $portText, prompt: Text("443 (default)"))
            }
            Section("Credentials") {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
            }
            Section {
                Toggle("Allow self-signed certificates", isOn: $allowSelfSigned)
                    .help("BMCs such as iDRAC usually present self-signed TLS certificates.")
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(isEditing ? "Save" : "Add") { save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
        .padding()
    }

    private func populate() {
        guard let server else { return }
        name = server.name
        host = server.host
        portText = server.port.map(String.init) ?? ""
        username = server.username
        allowSelfSigned = server.allowSelfSigned
        password = appState.store.password(for: server) ?? ""
    }

    private func save() {
        let port = Int(portText.trimmingCharacters(in: .whitespaces))
        let model = SavedServer(
            id: server?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            port: port,
            username: username.trimmingCharacters(in: .whitespaces),
            allowSelfSigned: allowSelfSigned
        )
        appState.store.save(model, password: password)
        dismiss()
    }
}
