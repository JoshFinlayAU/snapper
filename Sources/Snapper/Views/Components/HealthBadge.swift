import SwiftUI

/// A pill showing a Redfish health value with its symbol and colour.
struct HealthBadge: View {
    let health: RedfishHealth
    var label: String?
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: health.symbol)
                .foregroundStyle(health.color)
            if !compact {
                Text(label ?? health.label)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .background(
            Capsule().fill(health.color.opacity(0.15))
        )
        .overlay(
            Capsule().strokeBorder(health.color.opacity(0.35), lineWidth: 1)
        )
    }
}

/// A small coloured dot for inline status.
struct StatusDot: View {
    let health: RedfishHealth
    var body: some View {
        Circle()
            .fill(health.color)
            .frame(width: 9, height: 9)
            .overlay(Circle().strokeBorder(health.color.opacity(0.4), lineWidth: 2).scaleEffect(1.6))
    }
}
