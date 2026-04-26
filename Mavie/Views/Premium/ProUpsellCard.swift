import SwiftUI

/// Soft, on-brand upsell shown in place of Pro-only content for free users.
/// Tap presents the paywall.
struct ProUpsellCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let highlights: [String]
    let onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            VStack(spacing: MavieSpacing.md) {
                ZStack {
                    Circle().fill(MavieColor.lavender).frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(MavieColor.primaryPlum)
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MavieColor.primaryPlum.opacity(0.85))
                        .offset(x: 22, y: -22)
                }

                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(MavieColor.deepPlumText)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(highlights, id: \.self) { item in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(MavieColor.successSage)
                                Text(item)
                                    .font(MavieFont.subheadline)
                                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.8))
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Unlock Mavie Pro")
                }
                .font(MavieFont.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MavieSpacing.lg)
                .padding(.vertical, MavieSpacing.sm + 2)
                .background(MavieColor.primaryPlum, in: Capsule())
            }
            .padding(MavieSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        MavieColor.cardWhite,
                        MavieColor.lavender.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: MavieRadius.cardLarge, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MavieRadius.cardLarge, style: .continuous)
                    .stroke(MavieColor.primaryPlum.opacity(0.2), lineWidth: 1)
            )
            .mavieShadow(.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). Unlock Mavie Pro.")
    }
}

#Preview {
    ProUpsellCard(
        title: "Unlock advanced insights",
        subtitle: "See cycle length trends, symptom patterns, and mood charts.",
        icon: "chart.line.uptrend.xyaxis",
        highlights: ["Cycle length trends", "Symptom frequency", "Mood patterns", "Pain over time"]
    ) {}
        .padding()
        .background(MavieColor.backgroundCream)
}
