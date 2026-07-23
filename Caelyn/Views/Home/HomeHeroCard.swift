import SwiftUI

struct HomeHeroCard: View {
    let cycleDay: Int
    let cycleLength: Int
    let periodLength: Int
    let phase: CyclePhase
    let daysUntilPeriod: Int
    let predictedWindow: ClosedRange<Date>?
    var variation: Int = 0
    var confidence: Confidence = .low
    /// When present (1+ cycle), the phase hint becomes a personalized teaching
    /// line, and tapping the badge opens the personalized guide. Nil = the static
    /// hint + generic guide (day-1 users see exactly today's app).
    var personal: PhaseGuidePersonal? = nil

    @State private var showingPhaseGuide = false
    @State private var personalLine: String?
    @State private var isThinking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    Group {
                        if isThinking {
                            ThinkingIndicator(accent: phase.accentColor)
                        } else {
                            Text(personalLine ?? phase.hint)
                                .font(CaelynFont.subheadline.weight(.medium))
                                .foregroundStyle(phase.accentColor.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isThinking)
                    .animation(.easeInOut(duration: 0.35), value: personalLine)
                }

                if let predictedWindow {
                    HStack(spacing: 4) {
                        Text(HomeCopy.windowText(predictedWindow))
                        if variation > 1 {
                            Text("±\(variation) days")
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        }
                    }
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                }
                if confidence == .low {
                    Text("Log a few more cycles and predictions will improve")
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
        .sheet(isPresented: $showingPhaseGuide) {
            PhaseGuideView(phase: phase, personal: personal)
                .presentationDetents([.large])
        }
        // Reload when the day OR the phase changes (phase can flip mid-session
        // when logging shifts period/luteal length). Reset to the static hint
        // first so a stale wrong-phase line never lingers during the reload.
        .task(id: "\(cycleDay)-\(phase)") {
            personalLine = nil
            guard let facts = personal?.teaching else { isThinking = false; return }
            guard !reduceMotion else {
                personalLine = await CycleSummaryService.dailyTeaching(facts: facts)
                return
            }
            // A brief "Caelyn is thinking about you" beat before the personalized
            // line fades in — gives the app a mind that's paying attention to HER.
            isThinking = true
            async let line = CycleSummaryService.dailyTeaching(facts: facts)
            try? await Task.sleep(for: .milliseconds(850))
            let resolved = await line
            personalLine = resolved
            isThinking = false
        }
    }

    private var phaseBadge: some View {
        Button {
            showingPhaseGuide = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: phase.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(phase.displayName)
                    .font(CaelynFont.footnote.weight(.semibold))
                    .tracking(0.3)
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .regular))
                    .opacity(0.65)
            }
            .foregroundStyle(phase.accentColor)
            .padding(.horizontal, CaelynSpacing.sm)
            .padding(.vertical, 6)
            .background(phase.tintBackground.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Learn about the \(phase.displayName) phase")
        .accessibilityHint("Opens a guide to what's happening in your cycle right now")
    }

    private var phaseLegend: some View {
        HStack(spacing: CaelynSpacing.md) {
            legendDot(color: CaelynColor.softRose, label: "Period")
            legendDot(color: CaelynColor.successSage, label: "Ovulation")
            legendDot(color: CaelynColor.primaryPlum.opacity(0.55), label: "PMS")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend: rose for period, green for ovulation, purple for PMS")
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(label)
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
        }
    }
}

/// A brief "Caelyn is thinking about you" indicator — three phase-tinted dots
/// pulsing in sequence — shown while the personalized line is computed. Transient
/// (lives < 1s), so its looping dots stop as soon as it disappears.
private struct ThinkingIndicator: View {
    let accent: Color
    @State private var animating = false

    var body: some View {
        HStack(spacing: 7) {
            Text("Caelyn is reading your cycle")
                .font(CaelynFont.subheadline.weight(.medium))
                .foregroundStyle(accent.opacity(0.75))
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .opacity(animating ? 1.0 : 0.35)
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.18),
                            value: animating
                        )
                }
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel("Caelyn is reading your cycle")
    }
}
