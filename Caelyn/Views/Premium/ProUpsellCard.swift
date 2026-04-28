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
            VStack(spacing: CaelynSpacing.md) {
                ZStack {
                    Circle().fill(CaelynColor.lavender).frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(CaelynColor.primaryPlum.opacity(0.85))
                        .offset(x: 22, y: -22)
                }

                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(highlights, id: \.self) { item in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(CaelynColor.successSage)
                                Text(item)
                                    .font(CaelynFont.subheadline)
                                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.8))
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Unlock Caelyn Pro")
                }
                .font(CaelynFont.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, CaelynSpacing.lg)
                .padding(.vertical, CaelynSpacing.sm + 2)
                .background(CaelynColor.primaryPlum, in: Capsule())
            }
            .padding(CaelynSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        CaelynColor.cardWhite,
                        CaelynColor.lavender.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous)
                    .stroke(CaelynColor.primaryPlum.opacity(0.2), lineWidth: 1)
            )
            .caelynShadow(.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). Unlock Caelyn Pro.")
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
        .background(CaelynColor.backgroundCream)
}
