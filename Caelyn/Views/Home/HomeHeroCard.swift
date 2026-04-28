import SwiftUI

struct HomeHeroCard: View {
    let cycleDay: Int
    let cycleLength: Int
    let periodLength: Int
    let phase: CyclePhase
    let daysUntilPeriod: Int
    let predictedWindow: ClosedRange<Date>?

    var body: some View {
        VStack(spacing: CaelynSpacing.md) {
            phaseBadge
            CycleRingView(
                cycleDay: cycleDay,
                cycleLength: cycleLength,
                periodLength: periodLength,
                size: 240
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, CaelynSpacing.xs)

            VStack(spacing: 6) {
                Text(HomeCopy.phaseHeadline(phase, cycleDay: cycleDay, daysUntilPeriod: daysUntilPeriod))
                    .font(CaelynFont.title3.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .multilineTextAlignment(.center)

                // Phase-aware gentle hint — "Take it easy today" / "Be gentle
                // with yourself" / "A fresh-energy phase" — the warm one-liner
                // that turns a tracker into a companion. Suppressed for the
                // unknown phase since the headline already says "Welcome to
                // Caelyn" and the hint would be redundant.
                if phase != .unknown {
                    Text(phase.hint)
                        .font(CaelynFont.subheadline.weight(.medium))
                        .foregroundStyle(phase.accentColor.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                if let predictedWindow {
                    Text(HomeCopy.windowText(predictedWindow))
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                }
            }
            .padding(.horizontal, CaelynSpacing.sm)

            phaseLegend
                .padding(.top, CaelynSpacing.xs)
        }
        .padding(.vertical, CaelynSpacing.lg)
        .padding(.horizontal, CaelynSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CaelynColor.cardWhite,
                            phase.tintBackground.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous)
                .stroke(phase.accentColor.opacity(0.15), lineWidth: 1)
        )
        .caelynShadow(.card)
    }

    private var phaseBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: phase.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(phase.displayName)
                .font(CaelynFont.footnote.weight(.semibold))
                .tracking(0.3)
        }
        .foregroundStyle(phase.accentColor)
        .padding(.horizontal, CaelynSpacing.sm)
        .padding(.vertical, 6)
        .background(phase.tintBackground.opacity(0.7), in: Capsule())
    }

    private var phaseLegend: some View {
        HStack(spacing: CaelynSpacing.md) {
            legendDot(color: CaelynColor.softRose, label: "Period")
            legendDot(color: CaelynColor.successSage, label: "Ovulation")
            legendDot(color: CaelynColor.primaryPlum.opacity(0.55), label: "PMS")
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
        }
    }
}
