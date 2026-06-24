import SwiftUI

/// Shared visual language for the app: colours, gradients, and reusable styling.
enum Theme {
    static let accent = Color(red: 0.20, green: 0.55, blue: 0.95)
    static let accentSecondary = Color(red: 0.45, green: 0.30, blue: 0.95)

    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)

    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func gaugeGradient(for fraction: Double) -> AngularGradient {
        let colors: [Color]
        switch fraction {
        case ..<0.6: colors = [.green, .mint]
        case ..<0.85: colors = [.yellow, .orange]
        default: colors = [.orange, .red]
        }
        return AngularGradient(colors: colors, center: .center)
    }

    static func tint(for fraction: Double) -> Color {
        switch fraction {
        case ..<0.6: return .green
        case ..<0.85: return .orange
        default: return .red
        }
    }
}

/// The app's "redfish" logo, loaded from the bundled PNG with an SF Symbol fallback.
struct BrandLogo: View {
    var size: CGFloat = 64

    var body: some View {
        if let url = Bundle.module.url(forResource: "redfish", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .accessibilityLabel("Snapper")
        } else {
            Image(systemName: "server.rack")
                .font(.system(size: size * 0.8))
                .foregroundStyle(Theme.headerGradient)
        }
    }
}

/// A rounded translucent card container used throughout the dashboard.
struct Card<Content: View>: View {
    var title: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 6) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(Theme.accent)
                    }
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
