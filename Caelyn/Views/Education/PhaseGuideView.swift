import SwiftUI

struct PhaseGuideView: View {
    let phase: CyclePhase
    @Environment(\.dismiss) private var dismiss

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

    // MARK: - Guide data

    private var guide: PhaseGuide { PhaseGuide.guide(for: phase) }
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
