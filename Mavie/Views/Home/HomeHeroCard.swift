import SwiftUI

struct HomeHeroCard: View {
    let cycleDay: Int
    let cycleLength: Int
    let periodLength: Int
    let phase: CyclePhase
    let daysUntilPeriod: Int
    let predictedWindow: ClosedRange<Date>?

    var body: some View {
        VStack(spacing: MavieSpacing.md) {
            phaseBadge
            CycleRingView(
                cycleDay: cycleDay,
                cycleLength: cycleLength,
                periodLength: periodLength,
                size: 240
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, MavieSpacing.xs)

            VStack(spacing: 6) {
                Text(HomeCopy.phaseHeadline(phase, cycleDay: cycleDay, daysUntilPeriod: daysUntilPeriod))
                    .font(MavieFont.title3.weight(.semibold))
                    .foregroundStyle(MavieColor.deepPlumText)
                    .multilineTextAlignment(.center)

                // Phase-aware gentle hint — "Take it easy today" / "Be gentle
                // with yourself" / "A fresh-energy phase" — the warm one-liner
                // that turns a tracker into a companion. Suppressed for the
                // unknown phase since the headline already says "Welcome to
                // Mavie" and the hint would be redundant.
                if phase != .unknown {
                    Text(phase.hint)
                        .font(MavieFont.subheadline.weight(.medium))
                        .foregroundStyle(phase.accentColor.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                if let predictedWindow {
                    Text(HomeCopy.windowText(predictedWindow))
                        .font(MavieFont.caption)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
                }
            }
            .padding(.horizontal, MavieSpacing.sm)

            phaseLegend
                .padding(.top, MavieSpacing.xs)
        }
        .padding(.vertical, MavieSpacing.lg)
        .padding(.horizontal, MavieSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: MavieRadius.cardLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            MavieColor.cardWhite,
                            phase.tintBackground.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: MavieRadius.cardLarge, style: .continuous)
                .stroke(phase.accentColor.opacity(0.15), lineWidth: 1)
        )
        .mavieShadow(.card)
    }

    private var phaseBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: phase.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(phase.displayName)
                .font(MavieFont.footnote.weight(.semibold))
                .tracking(0.3)
        }
        .foregroundStyle(phase.accentColor)
        .padding(.horizontal, MavieSpacing.sm)
        .padding(.vertical, 6)
        .background(phase.tintBackground.opacity(0.7), in: Capsule())
    }

    private var phaseLegend: some View {
        HStack(spacing: MavieSpacing.md) {
            legendDot(color: MavieColor.softRose, label: "Period")
            legendDot(color: MavieColor.successSage, label: "Ovulation")
            legendDot(color: MavieColor.primaryPlum.opacity(0.55), label: "PMS")
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(MavieFont.caption)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
        }
    }
}
