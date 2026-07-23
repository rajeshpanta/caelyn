import SwiftUI

/// Everything the personalized guide sections need — bundled so the sheet stays
/// synchronous and deterministic. Nil `personal` = the plain generic guide (every
/// existing call site still works unchanged).
struct PhaseGuidePersonal {
    let teaching: CycleSummaryService.TeachingFacts
    let avgCycle: Int?
    let periodLength: Int?
    let variation: Int?
    let avgPain: Int?
    let learnedLuteal: Int?
    let pmsDaysBefore: Int?
    var gentle: Bool { teaching.gentle }
    var phase: CyclePhase { teaching.phase }
}

struct PhaseGuideView: View {
    let phase: CyclePhase
    var personal: PhaseGuidePersonal? = nil
    @Environment(\.dismiss) private var dismiss

    @AppStorage("caelyn.seenLearnedLuteal") private var seenLearnedLuteal = false
    @AppStorage("caelyn.seenLearnedPms") private var seenLearnedPms = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    phaseBanner
                    content
                        .padding(.horizontal, CaelynSpacing.lg)
                        .padding(.top, CaelynSpacing.lg)
                        .padding(.bottom, CaelynSpacing.xl)
                }
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Phase guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    // MARK: - Banner

    private var phaseBanner: some View {
        HStack(spacing: CaelynSpacing.md) {
            Image(systemName: phase.icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(phase.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(guide.name)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text(guide.daysRange)
                    .font(CaelynFont.caption.weight(.medium))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
            }
            Spacer()
        }
        .padding(CaelynSpacing.lg)
        .background(
            LinearGradient(
                colors: [phase.tintBackground.opacity(0.6), phase.tintBackground.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Content sections

    private var content: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
            if let personal {
                todayForYou(personal)
                isThisNormal(personal)
                commonQuestions(personal)
                whatCaelynLearned(personal)
                Divider().padding(.vertical, CaelynSpacing.xs)
            }
            guideSection(
                icon: "waveform.path",
                title: "What's happening",
                body: guide.whatIsHappening,
                tint: phase.accentColor
            )
            guideSection(
                icon: "heart.text.square",
                title: "How you might feel",
                body: guide.howYouFeel,
                tint: phase.accentColor
            )
            tipsSection
            if let hormone = guide.hormoneNote {
                hormoneNote(hormone)
            }
        }
    }

    private func guideSection(icon: String, title: String, body: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(CaelynFont.headline)
                    .foregroundStyle(CaelynColor.deepPlumText)
            }
            Text(body)
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CaelynColor.warmSand)
                Text("Tips for this phase")
                    .font(CaelynFont.headline)
                    .foregroundStyle(CaelynColor.deepPlumText)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(guide.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(phase.accentColor)
                            .padding(.top, 1)
                        Text(tip)
                            .font(CaelynFont.body)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func hormoneNote(_ text: String) -> some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                Image(systemName: "flask.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hormones")
                        .font(CaelynFont.caption.weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    Text(text)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Personalized sections (the tutor)

    private func todayForYou(_ p: PhaseGuidePersonal) -> some View {
        CaelynCard(padding: CaelynSpacing.md, background: phase.tintBackground.opacity(0.45)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(phase.accentColor)
                    Text("Today for you")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                }
                Text(CycleSummaryService.teachingFallback(facts: p.teaching))
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func isThisNormal(_ p: PhaseGuidePersonal) -> some View {
        let frames: [TypicalRanges.Frame] = [
            TypicalRanges.cycleLength(p.avgCycle, gentle: p.gentle),
            TypicalRanges.periodLength(p.periodLength, gentle: p.gentle),
            TypicalRanges.variation(p.variation, gentle: p.gentle),
            TypicalRanges.pain(p.avgPain)
        ].compactMap { $0 }

        return VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            sectionHeader(icon: "checkmark.seal", title: "Is this normal?", tint: phase.accentColor)
            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                    ForEach(Array(frames.enumerated()), id: \.offset) { idx, frame in
                        normalRow(frame)
                        if idx < frames.count - 1 {
                            Rectangle().fill(CaelynColor.deepPlumText.opacity(0.06)).frame(height: 1)
                        }
                    }
                    Text(TypicalRanges.footer)
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func normalRow(_ frame: TypicalRanges.Frame) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(frame.title)
                    .font(CaelynFont.callout.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText)
                Spacer(minLength: 0)
                Text(frame.herValue)
                    .font(CaelynFont.callout.weight(.semibold))
                    .foregroundStyle(frame.known ? phase.accentColor : CaelynColor.deepPlumText.opacity(0.4))
            }
            Text(frame.typical)
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
            Text(frame.status.text)
                .font(CaelynFont.caption.weight(.medium))
                .foregroundStyle(statusColor(frame.status))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(frame.title): \(frame.herValue). \(frame.typical). \(frame.status.text)")
    }

    private func statusColor(_ status: TypicalRanges.Status) -> Color {
        switch status {
        case .inRange:  return CaelynColor.successSage
        case .watch:    return CaelynColor.primaryPlum   // calm, never alarming red
        case .learning: return CaelynColor.deepPlumText.opacity(0.45)
        }
    }

    private func commonQuestions(_ p: PhaseGuidePersonal) -> some View {
        let qas = GuideQuestions.forToday(phase: p.phase, avgCycle: p.avgCycle, variation: p.variation, gentle: p.gentle)
        return VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            sectionHeader(icon: "bubble.left.and.text.bubble.right", title: "Common questions", tint: phase.accentColor)
            VStack(spacing: CaelynSpacing.xs) {
                ForEach(qas) { qa in
                    QuestionRow(qa: qa, accent: phase.accentColor)
                }
            }
        }
    }

    private func whatCaelynLearned(_ p: PhaseGuidePersonal) -> some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            sectionHeader(icon: "brain.head.profile", title: "What Caelyn has learned about you", tint: phase.accentColor)
            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                    learnedRow(
                        learned: p.learnedLuteal != nil,
                        highlight: p.learnedLuteal != nil && !seenLearnedLuteal,
                        learnedText: p.learnedLuteal.map { "✓ Your luteal phase is \($0) days — your ovulation estimate now uses it, not the textbook 14." } ?? "",
                        pendingText: "Your luteal phase — log ovulation tests across about 3 cycles and Caelyn learns your real number."
                    )
                    Rectangle().fill(CaelynColor.deepPlumText.opacity(0.06)).frame(height: 1)
                    learnedRow(
                        learned: p.pmsDaysBefore != nil,
                        highlight: p.pmsDaysBefore != nil && !seenLearnedPms,
                        learnedText: p.pmsDaysBefore.map { "✓ Your PMS usually starts about \($0) day\($0 == 1 ? "" : "s") before your period." } ?? "",
                        pendingText: "Your PMS timing — keep logging symptoms and moods, and Caelyn learns when yours actually begins."
                    )
                }
            }
        }
        // Mark "seen" only when the sheet CLOSES — so the sage highlight is
        // actually visible during this viewing, then won't highlight again.
        .onDisappear {
            if p.learnedLuteal != nil { seenLearnedLuteal = true }
            if p.pmsDaysBefore != nil { seenLearnedPms = true }
        }
    }

    private func learnedRow(learned: Bool, highlight: Bool, learnedText: String, pendingText: String) -> some View {
        HStack(alignment: .top, spacing: CaelynSpacing.sm) {
            Image(systemName: learned ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(learned ? CaelynColor.successSage : CaelynColor.deepPlumText.opacity(0.35))
                .padding(.top, 1)
            Text(learned ? learnedText : pendingText)
                .font(CaelynFont.subheadline)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(learned ? 0.85 : 0.6))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(highlight ? CaelynSpacing.xs : 0)
        .background(
            highlight
                ? RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous).fill(CaelynColor.successSage.opacity(0.12))
                : nil
        )
    }

    private func sectionHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(CaelynFont.headline)
                .foregroundStyle(CaelynColor.deepPlumText)
        }
    }

    // MARK: - Guide data

    private var guide: PhaseGuide { PhaseGuide.guide(for: phase) }
}

/// One tappable question that expands its answer inline — no nested sheet, no
/// free-form input. Answers are deterministic and provider-forward.
private struct QuestionRow: View {
    let qa: GuideQuestions.QA
    let accent: Color
    @State private var expanded = false

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(alignment: .leading, spacing: expanded ? 8 : 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: CaelynSpacing.sm) {
                        Text(qa.question)
                            .font(CaelynFont.callout.weight(.medium))
                            .foregroundStyle(CaelynColor.deepPlumText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    Text(qa.answer)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(expanded ? "Expanded" : "Tap to read the answer")
    }
}

// MARK: - Guide content model

private struct PhaseGuide {
    let name: String
    let daysRange: String
    let whatIsHappening: String
    let howYouFeel: String
    let tips: [String]
    let hormoneNote: String?

    static func guide(for phase: CyclePhase) -> PhaseGuide {
        switch phase {
        case .menstrual:
            return PhaseGuide(
                name: "Menstrual phase",
                daysRange: "Days 1–5",
                whatIsHappening: "Your uterus is shedding its lining. Estrogen and progesterone are at their lowest point. Your body is doing real, energy-intensive work.",
                howYouFeel: "Fatigue, cramps, lower back ache, and reduced energy are common. Many people feel more introverted and reflective right now.",
                tips: [
                    "Rest more than usual — this is one of the highest-energy-expenditure phases",
                    "Gentle movement (walking, yoga, stretching) can ease cramps",
                    "Iron-rich foods like leafy greens, lentils, and red meat help replenish",
                    "Heat on your abdomen can meaningfully reduce cramp intensity",
                    "Reduce caffeine and alcohol, which can worsen bloating and cramps"
                ],
                hormoneNote: "Estrogen and progesterone are at their cycle nadir, which is why energy and mood are lower. This is physiological, not personal."
            )
        case .follicular:
            return PhaseGuide(
                name: "Follicular phase",
                daysRange: "Days 6–12",
                whatIsHappening: "Your pituitary gland releases FSH, stimulating follicles in your ovaries to grow. The dominant follicle produces rising estrogen, which rebuilds the uterine lining.",
                howYouFeel: "Energy, mood, and focus typically improve noticeably. Many people feel their most sociable and creative during this phase.",
                tips: [
                    "Great time to start new projects or tackle challenging tasks",
                    "Higher-intensity workouts — your body handles load well now",
                    "Social plans, presentations, or important conversations fit this phase",
                    "Lean into creative brainstorming and open-ended thinking",
                    "Pay attention to cervical mucus — it helps confirm where you are in your cycle"
                ],
                hormoneNote: "Rising estrogen improves serotonin sensitivity, verbal fluency, and working memory. This is why analytical and social tasks feel easier."
            )
        case .ovulation:
            return PhaseGuide(
                name: "Ovulation",
                daysRange: "Days 12–16 (varies)",
                whatIsHappening: "An LH surge triggers the release of a mature egg from the dominant follicle. The egg is viable for 12–24 hours. Sperm can survive up to 5 days, making the fertile window slightly wider.",
                howYouFeel: "Peak energy, confidence, and libido for many people. Mild one-sided pelvic pain (mittelschmerz) is common and completely normal.",
                tips: [
                    "If TTC: the 2 days before and day of ovulation are peak fertility",
                    "LH strips turn positive 24–36 hours before ovulation — useful for timing",
                    "Cervical mucus becomes clear, stretchy, and egg-white-like at peak fertility",
                    "Log your BBT — it rises slightly (0.2–0.5°C) after ovulation",
                    "If avoiding pregnancy: use protection from 5 days before ovulation"
                ],
                hormoneNote: "The LH surge is sharp and short — typically 24–48 hours. Estrogen peaks just before it, driving the surge via a positive feedback loop."
            )
        case .luteal:
            return PhaseGuide(
                name: "Luteal phase",
                daysRange: "Days 17–26",
                whatIsHappening: "The emptied follicle becomes the corpus luteum, which secretes progesterone. Your body is preparing the uterine lining in case of pregnancy.",
                howYouFeel: "Calmer, more inward energy. Many people feel detail-oriented and introspective. Appetite often increases slightly; sleep may deepen.",
                tips: [
                    "Good phase for detailed, analytical, or solo work",
                    "Creative writing, cooking, and home projects often feel satisfying",
                    "Prioritize sleep — progesterone is slightly sedating and improves deep sleep",
                    "Moderate carbohydrate intake can help manage the serotonin dip",
                    "Nourishing meals with protein and complex carbs help stabilise mood"
                ],
                hormoneNote: "Progesterone dominates this phase. It raises basal body temperature, promotes GABA activity (calming), and can cause mild bloating and breast tenderness."
            )
        case .pms:
            return PhaseGuide(
                name: "PMS window",
                daysRange: "~5 days before period",
                whatIsHappening: "Estrogen and progesterone drop sharply as the corpus luteum breaks down (if no pregnancy occurred). This withdrawal triggers PMS symptoms in many people.",
                howYouFeel: "Irritability, anxiety, low mood, bloating, breast tenderness, and fatigue are the most common symptoms. For some, this phase is mild; for others it significantly affects daily life.",
                tips: [
                    "Reduce sodium to ease bloating (avoid processed foods)",
                    "Calcium (dairy, fortified foods, almonds) may reduce mood symptoms",
                    "Regular gentle exercise can ease irritability and cramps",
                    "Track your mood — patterns across cycles help identify triggers",
                    "If PMS significantly impacts your life, talk to a doctor about PMDD screening"
                ],
                hormoneNote: "The estrogen and progesterone drop triggers serotonin depletion, which underlies mood symptoms. This is a hormonal withdrawal, not a character trait."
            )
        case .unknown:
            return PhaseGuide(
                name: "Your menstrual cycle",
                daysRange: "28 days on average",
                whatIsHappening: "The menstrual cycle is divided into four main phases: menstrual (bleeding), follicular (rebuilding), ovulation (egg release), and luteal (preparation). Log your period start date to get personalised phase tracking.",
                howYouFeel: "Every phase brings different energy, mood, and physical sensations. Understanding your personal pattern is what Caelyn is built for.",
                tips: [
                    "Log your period start date to activate predictions",
                    "Daily symptom and mood logging builds your personal pattern",
                    "Cycle length can vary by 2–7 days between cycles — this is normal",
                    "Temperature and cervical mucus help confirm cycle phases",
                    "A 'normal' cycle ranges from 21–35 days in length"
                ],
                hormoneNote: nil
            )
        }
    }
}

#Preview {
    PhaseGuideView(phase: .luteal)
}
