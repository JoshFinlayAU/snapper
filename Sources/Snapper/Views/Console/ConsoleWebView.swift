import SwiftUI
import WebKit

/// Identifies a virtual-console window. Codable/Hashable so it can drive a `WindowGroup(for:)`.
struct ConsoleTarget: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var urlString: String
    var allowSelfSigned: Bool

    var url: URL? { URL(string: urlString) }
}

/// A `WKWebView` that hosts the iDRAC HTML5 interface / virtual console, accepting the
/// self-signed TLS certificates BMCs typically present.
struct ConsoleWebView: NSViewRepresentable {
    let url: URL
    let allowSelfSigned: Bool
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Snapper/1.0 (Macintosh)"
        webView.load(URLRequest(url: url))
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ConsoleWebView
        weak var webView: WKWebView?

        init(_ parent: ConsoleWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            guard parent.allowSelfSigned,
                  challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let trust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
    }
}

/// The full virtual-console window: a toolbar plus the embedded console web view.
struct ConsoleWindowView: View {
    let target: ConsoleTarget
    @State private var isLoading = false
    @State private var reloadToken = UUID()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "display")
                    .foregroundStyle(Theme.accent)
                Text(target.name)
                    .font(.headline)
                if isLoading {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Text(target.urlString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button { reloadToken = UUID() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload")
                Button {
                    if let url = target.url { NSWorkspace.shared.open(url) }
                } label: {
                    Image(systemName: "safari")
                }
                .help("Open in browser")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            Divider()

            if let url = target.url {
                ConsoleWebView(url: url, allowSelfSigned: target.allowSelfSigned, isLoading: $isLoading)
                    .id(reloadToken)
            } else {
                ContentUnavailableMessage(text: "Invalid console URL.")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

private struct ContentUnavailableMessage: View {
    let text: String
    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
