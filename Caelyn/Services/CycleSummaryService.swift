import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "Private Intelligence" — a warm, plain-language summary of the user's cycle.
///
/// Uses Apple's on-device **Foundation Models** when available (iOS 26 + Apple
/// Intelligence), and otherwise a deterministic template. BOTH paths run 100%
/// on-device with zero network. Only STRUCTURED facts are fed to the model —
/// never the user's free-form notes — and the model is instructed never to
/// diagnose or give medical advice (int-4).
enum CycleSummaryService {

    struct Facts {
        let avgCycle: Int
        let avgPeriod: Int
        let variation: Int
        let phaseName: String
        let cycleDay: Int
        let daysUntilPeriod: Int
        let topInsight: String?
    }

    /// Returns an on-device summary. Never throws and never blocks the UI badly:
    /// any failure in the AI path silently falls back to the template.
    static func summary(for facts: Facts) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                if let text = try? await generate(facts: facts),
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text
                }
            }
        }
        #endif
        return fallback(facts: facts)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generate(facts: Facts) async throws -> String {
        let session = LanguageModelSession(instructions: """
        You are a warm, plain-spoken women's-health companion inside a private, on-device period tracker. \
        Write 2 to 3 short, supportive sentences summarising the user's cycle using ONLY the facts provided. \
        Never diagnose, never give medical advice, and never invent numbers.
        """)
        let insightLine = facts.topInsight.map { " A pattern Caelyn noticed: \($0)." } ?? ""
        // The prompt is passed as an interpolated literal so it converts to the
        // model's Prompt type directly.
        let response = try await session.respond(to: """
        Average cycle length: \(facts.avgCycle) days. Average period length: \(facts.avgPeriod) days. \
        Cycle-length variation: plus or minus \(facts.variation) days. Today is cycle day \(facts.cycleDay), \
        in the \(facts.phaseName) phase, with the next period expected in about \(facts.daysUntilPeriod) days.\(insightLine)
        """)
        return response.content
    }
    #endif

    // MARK: - Daily teaching (the in-context tutor voice)

    struct TeachingFacts {
        let phase: CyclePhase
        let cycleDay: Int
        let cycleCount: Int
        /// A concise pattern observed for THIS phase, e.g.
        /// "You've logged low energy here in 4 of 5 cycles." (nil if none / too few).
        let topPatternLine: String?
        let gentle: Bool
    }

    /// One personalized teaching line for today, woven from HER data — the voice
    /// that turns a tracker into a tutor. Deterministic template is primary;
    /// Foundation Models may only REPHRASE it (same guardrails). Returns nil when
    /// there isn't enough data yet (caller keeps the static phase hint), so a
    /// day-1 user sees exactly today's app.
    static func dailyTeaching(facts: TeachingFacts) async -> String? {
        guard facts.cycleCount >= 1, facts.phase != .unknown else { return nil }
        let base = teachingFallback(facts: facts)
        guard !base.isEmpty else { return nil }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            if let text = try? await rephrase(base, gentle: facts.gentle),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        #endif
        return base
    }

    /// Deterministic teaching template (pure, unit-tested). Never diagnoses,
    /// never adds numbers the caller didn't supply.
    static func teachingFallback(facts: TeachingFacts) -> String {
        let lead = phaseLead(facts.phase, cycleDay: facts.cycleDay, gentle: facts.gentle)
        guard !lead.isEmpty else { return "" }
        guard let pattern = facts.topPatternLine, !pattern.isEmpty else { return lead }
        return facts.gentle
            ? "\(lead) \(pattern) That's your body's rhythm — not something wrong."
            : "\(lead) \(pattern) That's your pattern, not a flaw."
    }

    private static func phaseLead(_ phase: CyclePhase, cycleDay: Int, gentle: Bool) -> String {
        switch phase {
        case .menstrual:
            return gentle ? "Day \(cycleDay) — cramps and tiredness are common right now. Rest and warmth genuinely help."
                          : "Day \(cycleDay) — estrogen and progesterone are at their lowest, so lower energy is expected."
        case .follicular:
            return gentle ? "Day \(cycleDay) — your energy usually starts to lift around now."
                          : "Day \(cycleDay) — estrogen is rising, often bringing sharper focus and steadier energy."
        case .ovulation:
            return gentle ? "Day \(cycleDay) — around the middle of your cycle, when energy often peaks."
                          : "Day \(cycleDay) — around ovulation, when energy, mood, and libido often peak."
        case .luteal:
            return gentle ? "Day \(cycleDay) — a calmer, more inward stretch of your cycle."
                          : "Day \(cycleDay) — progesterone is rising, which tends to feel calmer and more inward."
        case .pms:
            return gentle ? "Your period is close. Mood dips and cravings are common right now — be gentle with yourself."
                          : "Day \(cycleDay) — hormones drop before your period, which can bring mood and energy dips. That's your biology, not laziness — rest is allowed."
        case .unknown:
            return ""
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func rephrase(_ line: String, gentle: Bool) async throws -> String {
        let tone = gentle
            ? "extra gentle, simple, and reassuring, as if speaking to someone new to having periods"
            : "warm, plain-spoken, and respectful"
        let session = LanguageModelSession(instructions: """
        You are a \(tone) women's-health companion in a private on-device app. Rephrase the given sentence in your own \
        warmer words, keeping it to 1 or 2 short sentences, keeping every fact identical, never diagnosing, and never \
        adding numbers or medical advice.
        """)
        let response = try await session.respond(to: line)
        return response.content
    }
    #endif

    /// Deterministic, always-available summary (used on every device, and as the
    /// fallback when the on-device model is unavailable or errors).
    static func fallback(facts: Facts) -> String {
        var parts: [String] = []
        parts.append("You're on day \(facts.cycleDay) of your cycle, in your \(facts.phaseName.lowercased()) phase.")
        if facts.daysUntilPeriod > 0 {
            parts.append("Your next period is expected in about \(facts.daysUntilPeriod) day\(facts.daysUntilPeriod == 1 ? "" : "s").")
        }
        var avg = "Your cycles average \(facts.avgCycle) days"
        if facts.variation > 1 { avg += " (give or take \(facts.variation))" }
        avg += ", with periods around \(facts.avgPeriod) days."
        parts.append(avg)
        if let insight = facts.topInsight { parts.append(insight) }
        return parts.joined(separator: " ")
    }
}
