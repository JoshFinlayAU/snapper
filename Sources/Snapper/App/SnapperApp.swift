import SwiftUI

@main
struct SnapperApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1180, minHeight: 800)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1440, height: 920)

        // Detached virtual-console (KVM) windows, one per opened target.
        WindowGroup(id: "console", for: ConsoleTarget.self) { $target in
            if let target {
                ConsoleWindowView(target: target)
            }
        }
        .defaultSize(width: 1100, height: 760)

        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Server…") {
                    NotificationCenter.default.post(name: .addServerRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .refreshRequested, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let addServerRequested = Notification.Name("Snapper.addServerRequested")
    static let refreshRequested = Notification.Name("Snapper.refreshRequested")
}
