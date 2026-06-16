import SwiftUI

struct PatternInsightsSection: View {
    let insights: [PatternInsight]
    let isPro: Bool
    var onUpgrade: () -> Void = {}

    private var visibleInsights: [PatternInsight] {
        isPro ? insights : Array(insights.prefix(2))
    }

    var body: some View {
        if insights.isEmpty { return AnyView(EmptyView()) }
        return AnyView(content)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(
                title: "Your Patterns",
                subtitle: "\(insights.count) insight\(insights.count == 1 ? "" : "s") from your cycle history"
            )

            VStack(spacing: CaelynSpacing.sm) {
                ForEach(visibleInsights) { insight in
                    PatternInsightCard(insight: insight)
                }

                if !isPro && insights.count > 2 {
                    lockedInsightsTeaser(remaining: insights.count - 2)
                }
            }
        }
    }

    private func lockedInsightsTeaser(remaining: Int) -> some View {
        Button(action: onUpgrade) {
            CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.lavender.opacity(0.45)) {
                HStack(spacing: CaelynSpacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(remaining) more insight\(remaining == 1 ? "" : "s") locked")
                            .font(CaelynFont.callout.weight(.semibold))
                            .foregroundStyle(CaelynColor.primaryPlum)
                        Text("Pro shows every pattern your cycle history contains.")
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CaelynColor.primaryPlum.opacity(0.6))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Single insight card

struct PatternInsightCard: View {
    let insight: PatternInsight

    private var accent: Color {
        switch insight.relatedPhase {
        case .menstrual:  return CaelynColor.softRose
        case .follicular: return CaelynColor.warmSand
        case .ovulation:  return CaelynColor.successSage
        case .luteal:     return CaelynColor.warmSand
        case .pms:        return CaelynColor.primaryPlum
        case .unknown, nil: return CaelynColor.primaryPlum
        }
    }

    private var icon: String {
        switch insight.category {
        case .phaseSymptom:       return "brain"
        case .prePeriodMood:      return "cloud.moon.fill"
        case .energyCurve:        return "bolt.circle.fill"
        case .cycleLengthTrend:   return "arrow.up.arrow.down.circle.fill"
        case .pmsPredictorSymptom: return "exclamationmark.circle.fill"
        case .painTrend:          return "heart.text.square.fill"
        case .frequentSymptom:    return "list.bullet.circle.fill"
        }
    }

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(CaelynFont.callout.weight(.semibold))
                            .foregroundStyle(CaelynColor.deepPlumText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(insight.body)
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let value = insight.supportingValue {
                    HStack(spacing: 6) {
                        Text(value)
                            .font(CaelynFont.caption.weight(.semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.12), in: Capsule())

                        confidenceDots
                    }
                } else {
                    confidenceDots
                }
            }
        }
    }

    private var confidenceDots: some View {
        let filled = Int((insight.confidence * 3).rounded())
        return HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < filled ? accent : CaelynColor.deepPlumText.opacity(0.15))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel("Confidence: \(filled) of 3")
    }
}
