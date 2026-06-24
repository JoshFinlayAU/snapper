import SwiftUI

/// A circular progress gauge with a centre value, used for power and temperature.
struct RadialGauge: View {
    let fraction: Double          // 0.0 – 1.0
    let valueText: String
    let caption: String
    var subCaption: String?

    private var clamped: Double { min(max(fraction, 0), 1) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        Theme.gaugeGradient(for: clamped),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: clamped)

                VStack(spacing: 2) {
                    Text(valueText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.tint(for: clamped))
                    if let subCaption {
                        Text(subCaption)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 130, height: 130)

            Text(caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

/// A horizontal bar gauge for compact metric rows (e.g. per-fan, per-temp).
struct BarGauge: View {
    let fraction: Double
    var height: CGFloat = 8

    private var clamped: Double { min(max(fraction, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(Theme.tint(for: clamped))
                    .frame(width: max(geo.size.width * clamped, 4))
                    .animation(.easeInOut(duration: 0.5), value: clamped)
            }
        }
        .frame(height: height)
    }
}
