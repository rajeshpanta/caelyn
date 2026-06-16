import Foundation
import SwiftData

/// Seeds rich, visually compelling demo data for App Store screenshot capture.
/// Active only when the app is launched with --screenshot-mode.
///
/// Cycle position: Day 14 (ovulation) — the most visually interesting state.
/// Includes 5 full historical cycles plus the current one, with BBT readings,
/// energy levels, symptom severity, ovulation test results, and mood data so
/// every screen looks populated and real.
@MainActor
enum ScreenshotSeeder {

    static func populate(_ context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Day 14 of a 28-day cycle — right at ovulation
        guard let lastPeriodStart = cal.date(byAdding: .day, value: -13, to: today) else { return }

        let profile = UserProfile(
            averageCycleLength: 28,
            averagePeriodLength: 5,
            trackingGoals: [.period, .symptoms, .mood, .ovulation, .fertileWindow],
            hasOnboarded: true,
            lastPeriodStart: lastPeriodStart
        )
        context.insert(profile)

        // 5 historical complete cycles + current cycle up to today
        let specs: [(daysAgo: Int, len: Int, pLen: Int)] = [
            (daysAgo: 13,  len: 28, pLen: 5),   // current
            (daysAgo: 41,  len: 28, pLen: 5),
            (daysAgo: 70,  len: 29, pLen: 6),
            (daysAgo: 98,  len: 27, pLen: 4),
            (daysAgo: 126, len: 28, pLen: 5),
            (daysAgo: 154, len: 29, pLen: 5)
        ]

        for (idx, spec) in specs.enumerated() {
            guard let cycleStart = cal.date(byAdding: .day, value: -spec.daysAgo, to: today) else { continue }
            let isCurrent = idx == 0
            let logDays = isCurrent ? min(spec.daysAgo + 1, spec.len) : spec.len
            for dayOffset in 0..<logDays {
                let cycleDay = dayOffset + 1
                guard let date = cal.date(byAdding: .day, value: dayOffset, to: cycleStart) else { continue }
                let entry = makeEntry(date: date, cycleDay: cycleDay, spec: spec, isCurrent: isCurrent)
                if entry.hasContent { context.insert(entry) }
            }
        }

        try? context.save()
    }

    // MARK: - Entry factory

    private static func makeEntry(
        date: Date,
        cycleDay: Int,
        spec: (daysAgo: Int, len: Int, pLen: Int),
        isCurrent: Bool
    ) -> CycleEntry {
        let entry = CycleEntry(date: date)
        let ovDay = spec.len - 14
        let pmsStart = spec.len - 5

        switch cycleDay {
        // --- Menstrual phase ---
        case 1...spec.pLen:
            entry.flow = periodFlow(cycleDay, spec.pLen)
            entry.pain = periodPain(cycleDay)
            entry.painTypes = cycleDay <= 2 ? [.cramps, .backPain] : [.cramps]
            entry.symptoms = cycleDay <= 2 ? [.cramps, .fatigue, .bloating] : [.cramps, .fatigue]
            entry.symptomSeverity = [Symptom.cramps.rawValue: cycleDay == 2 ? 3 : 2,
                                     Symptom.fatigue.rawValue: 2]
            entry.mood = cycleDay <= 2 ? .tired : .calm
            entry.energyLevel = cycleDay <= 2 ? .drained : .low
            entry.basalTemperature = bbt(cycleDay: cycleDay, cycleLength: spec.len)
            if cycleDay == 1 { entry.note = "Period started — using heating pad today." }

        // --- Follicular phase ---
        case (spec.pLen + 1)..<ovDay:
            entry.mood = cycleDay < 8 ? .calm : .happy
            entry.energyLevel = cycleDay < 8 ? .moderate : .high
            entry.basalTemperature = bbt(cycleDay: cycleDay, cycleLength: spec.len)
            if cycleDay % 4 == 0 { entry.symptoms = [.cravings] }

        // --- Ovulation ---
        case ovDay...(ovDay + 1):
            entry.mood = .energetic
            entry.energyLevel = .energized
            entry.symptoms = [.cravings]
            entry.cervicalMucus = .eggWhite
            entry.ovulationTestResult = cycleDay == ovDay ? .lhSurge : .positive
            entry.basalTemperature = bbt(cycleDay: cycleDay, cycleLength: spec.len)
            if cycleDay == ovDay { entry.note = "LH surge detected — peak fertility window." }

        // --- Post-ovulation / luteal ---
        case (ovDay + 2)..<pmsStart:
            entry.energyLevel = .moderate
            entry.basalTemperature = bbt(cycleDay: cycleDay, cycleLength: spec.len)
            if cycleDay % 5 == 0 { entry.mood = .calm }

        // --- PMS ---
        case pmsStart...:
            let daysFromEnd = spec.len - cycleDay
            entry.symptoms = pmsSymptoms(daysFromEnd: daysFromEnd)
            entry.symptomSeverity = [Symptom.bloating.rawValue: 2, Symptom.acne.rawValue: 1]
            entry.mood = daysFromEnd <= 1 ? .moody : .sensitive
            entry.energyLevel = .low
            entry.pain = daysFromEnd <= 1 ? 3 : 1
            entry.basalTemperature = bbt(cycleDay: cycleDay, cycleLength: spec.len)

        default: break
        }

        return entry
    }

    // MARK: - Helpers

    private static func periodFlow(_ day: Int, _ pLen: Int) -> FlowLevel {
        switch day {
        case 1: return .light
        case 2: return .heavy
        case 3: return .medium
        case _ where day == pLen: return .spotting
        default: return .light
        }
    }

    private static func periodPain(_ day: Int) -> Int {
        switch day { case 1: return 4; case 2: return 7; case 3: return 5; default: return 2 }
    }

    private static func pmsSymptoms(daysFromEnd: Int) -> [Symptom] {
        switch daysFromEnd {
        case 0, 1: return [.bloating, .acne, .cravings, .headache]
        case 2:    return [.bloating, .acne]
        default:   return [.bloating]
        }
    }

    /// BBT pattern: low (~36.2) before ovulation, rises ~0.4°C after
    private static func bbt(cycleDay: Int, cycleLength: Int) -> Double? {
        let ovDay = cycleLength - 14
        let base = 36.20
        let post = 36.62
        let temp: Double
        switch cycleDay {
        case 1...2:         temp = base - 0.05   // slight drop during period
        case 3..<ovDay:     temp = base + Double(cycleDay - 3) * 0.01
        case ovDay:         temp = base + 0.10   // LH surge day — small pre-rise
        case (ovDay + 1)...: temp = post + Double.random(in: -0.04...0.06)
        default:            temp = base
        }
        // Add small daily variation for realism, only log every other day to keep data sparse enough
        guard cycleDay % 2 == 0 || cycleDay <= 5 || cycleDay >= (cycleLength - 6) else { return nil }
        return (temp * 10).rounded() / 10
    }
}
