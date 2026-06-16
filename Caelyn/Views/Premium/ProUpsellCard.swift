import SwiftUI

/// Soft, on-brand upsell shown in place of Pro-only content for free users.
/// Tap presents the paywall.
struct ProUpsellCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let highlights: [String]
    var featureIcons: [String] = []
    var reassurance: String = "Secure payment · Cancel anytime"
    let onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            VStack(spacing: 0) {
                // Plum gradient header band
                ZStack {
                    LinearGradient(
                        colors: [CaelynColor.primaryPlum, CaelynColor.primaryPlum.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: CaelynSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: icon)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, CaelynSpacing.lg)

                        if !featureIcons.isEmpty {
                            HStack(spacing: CaelynSpacing.md) {
                                ForEach(featureIcons, id: \.self) { fi in
                                    Image(systemName: fi)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(.bottom, CaelynSpacing.md)
                        } else {
                            Spacer().frame(height: CaelynSpacing.md)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: CaelynRadius.cardLarge,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: CaelynRadius.cardLarge,
                    style: .continuous
                ))

                // Body
                VStack(spacing: CaelynSpacing.md) {
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(CaelynColor.deepPlumText)
                            .multilineTextAlignment(.center)
                        Text(subtitle)
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !highlights.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(highlights, id: \.self) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(CaelynColor.successSage)
                                    Text(item)
                                        .font(CaelynFont.subheadline)
                                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.8))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                    }

                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Unlock Caelyn Pro")
                        }
                        .font(CaelynFont.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, CaelynSpacing.xl)
                        .padding(.vertical, CaelynSpacing.sm + 2)
                        .frame(maxWidth: .infinity)
                        .background(CaelynColor.primaryPlum, in: Capsule())

                        if !reassurance.isEmpty {
                            Text(reassurance)
                                .font(CaelynFont.caption)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
                        }
                    }
                }
                .padding(CaelynSpacing.lg)
                .background(
                    LinearGradient(
                        colors: [CaelynColor.cardWhite, CaelynColor.lavender.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: CaelynRadius.cardLarge,
                    bottomTrailingRadius: CaelynRadius.cardLarge,
                    topTrailingRadius: 0,
                    style: .continuous
                ))
            }
            .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous)
                    .stroke(CaelynColor.primaryPlum.opacity(0.18), lineWidth: 1)
            )
            .caelynShadow(.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle) Unlock Caelyn Pro.")
    }
}

#Preview {
    ProUpsellCard(
        title: "Your body has more to say",
        subtitle: "Pro unlocks the patterns that free can't show — cycle trends, mood shifts, and what your symptoms really mean.",
        icon: "chart.line.uptrend.xyaxis",
        highlights: [
            "Cycle & period length trends",
            "Symptom frequency over time",
            "Mood & pain charts",
            "Basal body temperature graph",
            "PDF report for your doctor",
            "TTC fertility scoring",
            "Apple Watch + Home Screen widgets"
        ],
        featureIcons: ["chart.bar.fill", "brain", "heart.text.square.fill", "doc.richtext.fill", "applewatch"]
    ) {}
        .padding()
        .background(CaelynColor.backgroundCream)
}
