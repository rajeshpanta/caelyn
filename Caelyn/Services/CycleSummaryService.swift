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
