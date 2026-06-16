import Foundation

// MARK: - Output types

enum InsightCategory: String, CaseIterable {
    case phaseSymptom
    case prePeriodMood
    case energyCurve
    case cycleLengthTrend
    case pmsPredictorSymptom
    case painTrend
    case frequentSymptom
}

struct PatternInsight: Identifiable {
    let id: UUID
    let category: InsightCategory
    let title: String
    let body: String
    let supportingValue: String?
    let confidence: Double      // 0.0–1.0
    let relatedPhase: CyclePhase?
    let discoveredAt: Date

    init(
        category: InsightCategory,
        title: String,
        body: String,
        supportingValue: String? = nil,
        confidence: Double,
        relatedPhase: CyclePhase? = nil,
        discoveredAt: Date = .now
    ) {
        self.id = UUID()
        self.category = category
        self.title = title
        self.body = body
        self.supportingValue = supportingValue
        self.confidence = confidence
        self.relatedPhase = relatedPhase
        self.discoveredAt = discoveredAt
    }
}

// MARK: - Engine

enum PatternEngine {

    private static let calendar = Calendar.current

    /// Run all pattern detectors and return insights sorted by confidence, highest first.
    /// Requires at least 2 completed cycles; returns empty array with fewer.
    static func insights(
        from entries: [CycleEntry],
        cycles: [Cycle],
        profile: UserProfile?
    ) -> [PatternInsight] {
        guard cycles.count >= 2 else { return [] }
        let cycleLength = profile?.averageCycleLength ?? 28
        let periodLength = profile?.averagePeriodLength ?? 5

        var results: [PatternInsight] = []

        if let insight = phaseSymptomCorrelation(entries: entries, cycles: cycles, cycleLength: cycleLength, periodLength: periodLength) {
            results.append(insight)
        }
        if let insight = prePeriodMoodDip(entries: entries, cycles: cycles) {
            results.append(insight)
        }
        if let insight = energyCurve(entries: entries, cycles: cycles, cycleLength: cycleLength, periodLength: periodLength) {
            results.append(insight)
        }
        if let insight = cycleLengthTrend(cycles: cycles) {
            results.append(insight)
        }
        if let insight = pmsPredictorSymptom(entries: entries, cycles: cycles) {
            results.append(insight)
        }
        if let insight = painTrend(entries: entries, cycles: cycles) {
            results.append(insight)
        }
        if let insight = frequentSymptomInsight(entries: entries) {
            results.append(insight)
        }

        return results.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Detectors

    /// Finds the symptom + phase pairing with the strongest correlation.
    /// Reports it if the symptom appears in that phase in ≥2 cycles and
    /// accounts for ≥40% of all its occurrences.
    private static func phaseSymptomCorrelation(
        entries: [CycleEntry],
        cycles: [Cycle],
        cycleLength: Int,
        periodLength: Int
    ) -> PatternInsight? {
        var phaseSymptomCounts: [Symptom: [CyclePhase: Int]] = [:]

        for entry in entries {
            guard let (day, cycle) = cycleDay(for: entry.date, in: cycles) else { continue }
            let phase = PredictionEngine.phase(forCycleDay: day, periodLength: cycle.periodLength, cycleLength: cycle.length)
            for symptom in entry.symptoms {
                phaseSymptomCounts[symptom, default: [:]][phase, default: 0] += 1
            }
        }

        var best: (symptom: Symptom, phase: CyclePhase, count: Int, total: Int)?
        for (symptom, phaseCounts) in phaseSymptomCounts {
            let total = phaseCounts.values.reduce(0, +)
            guard total >= 3 else { continue }
            if let top = phaseCounts.max(by: { $0.value < $1.value }) {
                let fraction = Double(top.value) / Double(total)
                guard fraction >= 0.4 else { continue }
                if best == nil || top.value > best!.count {
                    best = (symptom, top.key, top.value, total)
                }
            }
        }

        guard let b = best, b.count >= 2 else { return nil }
        let pct = Int(Double(b.count) / Double(b.total) * 100)
        let confidence = min(1.0, Double(b.count) / 6.0) * 0.85
        return PatternInsight(
            category: .phaseSymptom,
            title: "\(b.symptom.displayName) peaks in your \(b.phase.displayName) phase",
            body: "You've logged \(b.symptom.displayName.lowercased()) during your \(b.phase.displayName.lowercased()) phase in \(b.count) of your last cycles.",
            supportingValue: "\(pct)% of occurrences",
            confidence: confidence,
            relatedPhase: b.phase
        )
    }

    /// Detects if negative moods are significantly more common in the 5 days before period.
    private static func prePeriodMoodDip(entries: [CycleEntry], cycles: [Cycle]) -> PatternInsight? {
        let negativeMoods: Set<Mood> = [.anxious, .irritable, .moody, .sad, .sensitive, .lowEnergy]
        var prePeriodNegative = 0
        var prePeriodTotal = 0
        var otherNegative = 0
        var otherTotal = 0

        for entry in entries {
            guard let mood = entry.mood else { continue }
            let day = calendar.startOfDay(for: entry.date)
            let isNegative = negativeMoods.contains(mood)

            // Find which cycle comes next after this entry (to check if it's pre-period).
            let nextCycleStart = cycles
                .map(\.start)
                .filter { $0 > day }
                .min()

            if let next = nextCycleStart,
               let daysUntil = calendar.dateComponents([.day], from: day, to: next).day,
               daysUntil >= 1, daysUntil <= 5 {
                prePeriodTotal += 1
                if isNegative { prePeriodNegative += 1 }
            } else {
                otherTotal += 1
                if isNegative { otherNegative += 1 }
            }
        }

        guard prePeriodTotal >= 4, otherTotal >= 4 else { return nil }

        let prePeriodRate = Double(prePeriodNegative) / Double(prePeriodTotal)
        let otherRate = Double(otherNegative) / Double(otherTotal)
        guard prePeriodRate >= 0.45, prePeriodRate > otherRate * 1.7 else { return nil }

        let confidence = min(1.0, Double(prePeriodNegative) / 8.0) * 0.8
        return PatternInsight(
            category: .prePeriodMood,
            title: "Your mood often dips before your period",
            body: "In \(prePeriodNegative) of \(prePeriodTotal) days logged before your period, you've recorded a low mood — \(Int(prePeriodRate * 100))% of pre-period days vs \(Int(otherRate * 100))% otherwise.",
            supportingValue: "\(Int(prePeriodRate * 100))% vs \(Int(otherRate * 100))%",
            confidence: confidence,
            relatedPhase: .pms
        )
    }

    /// Finds the highest- and lowest-energy cycle phases.
    private static func energyCurve(
        entries: [CycleEntry],
        cycles: [Cycle],
        cycleLength: Int,
        periodLength: Int
    ) -> PatternInsight? {
        var phaseEnergy: [CyclePhase: [Int]] = [:]

        for entry in entries {
            guard let level = entry.energyLevel,
                  let (day, cycle) = cycleDay(for: entry.date, in: cycles) else { continue }
            let phase = PredictionEngine.phase(forCycleDay: day, periodLength: cycle.periodLength, cycleLength: cycle.length)
            let value = energyValue(level)
            phaseEnergy[phase, default: []].append(value)
        }

        let phaseAverages = phaseEnergy
            .filter { $0.value.count >= 2 }
            .mapValues { values in Double(values.reduce(0, +)) / Double(values.count) }

        guard phaseAverages.count >= 2 else { return nil }

        guard let high = phaseAverages.max(by: { $0.value < $1.value }),
              let low  = phaseAverages.min(by: { $0.value < $1.value }) else { return nil }
        guard high.value - low.value >= 1.2 else { return nil }

        let confidence = min(1.0, Double(phaseEnergy.values.flatMap { $0 }.count) / 12.0) * 0.75
        return PatternInsight(
            category: .energyCurve,
            title: "Energy peaks during your \(high.key.displayName) phase",
            body: "Your energy is highest during your \(high.key.displayName.lowercased()) phase and lowest during your \(low.key.displayName.lowercased()) phase — a \(String(format: "%.1f", high.value - low.value))-point difference on average.",
            supportingValue: "\(high.key.displayName) → \(low.key.displayName)",
            confidence: confidence,
            relatedPhase: high.key
        )
    }

    /// Detects whether recent cycles are trending shorter or longer.
    private static func cycleLengthTrend(cycles: [Cycle]) -> PatternInsight? {
        guard cycles.count >= 6 else { return nil }
        let recent = cycles.suffix(3).map(\.length)
        let older  = cycles.dropLast(3).suffix(3).map(\.length)
        let avgRecent = Double(recent.reduce(0, +)) / Double(recent.count)
        let avgOlder  = Double(older.reduce(0, +)) / Double(older.count)
        let delta = avgRecent - avgOlder
        guard abs(delta) >= 3.0 else { return nil }

        let direction = delta > 0 ? "longer" : "shorter"
        let oldStr = String(format: "%.0f", avgOlder)
        let newStr = String(format: "%.0f", avgRecent)
        return PatternInsight(
            category: .cycleLengthTrend,
            title: "Your cycles have been getting \(direction)",
            body: "Your average cycle length has shifted from \(oldStr) days to \(newStr) days over your recent cycles. This could be normal variation or a sign of hormonal change worth discussing with your doctor.",
            supportingValue: "\(oldStr) → \(newStr) days",
            confidence: 0.7
        )
    }

    /// Finds a symptom that reliably appears in the 4 days before period start.
    private static func pmsPredictorSymptom(entries: [CycleEntry], cycles: [Cycle]) -> PatternInsight? {
        let windowDays = 4
        var hitCycles: [Symptom: Int] = [:]

        for cycle in cycles {
            let windowEnd = calendar.date(byAdding: .day, value: -1, to: cycle.start) ?? cycle.start
            let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: cycle.start) ?? cycle.start

            let windowEntries = entries.filter {
                let d = calendar.startOfDay(for: $0.date)
                return d >= windowStart && d <= windowEnd
            }
            let symptomsInWindow = Set(windowEntries.flatMap(\.symptoms))
            for s in symptomsInWindow { hitCycles[s, default: 0] += 1 }
        }

        let total = cycles.count
        guard total >= 3 else { return nil }

        let best = hitCycles
            .filter { Double($0.value) / Double(total) >= 0.6 && $0.value >= 3 }
            .max(by: { $0.value < $1.value })

        guard let b = best else { return nil }
        let pct = Int(Double(b.value) / Double(total) * 100)
        return PatternInsight(
            category: .pmsPredictorSymptom,
            title: "\(b.key.displayName) often signals your period is coming",
            body: "In \(pct)% of your cycles, \(b.key.displayName.lowercased()) appears in the 4 days before your period starts. It may be a reliable early signal for you.",
            supportingValue: "\(b.value) of \(total) cycles",
            confidence: min(1.0, Double(b.value) / 6.0) * 0.85,
            relatedPhase: .pms
        )
    }

    /// Compares average period pain between recent and older cycles.
    private static func painTrend(entries: [CycleEntry], cycles: [Cycle]) -> PatternInsight? {
        guard cycles.count >= 6 else { return nil }
        let recentCycles = Array(cycles.suffix(3))
        let olderCycles  = Array(cycles.dropLast(3).suffix(3))

        let recentPain = avgPainInCycles(recentCycles, entries: entries)
        let olderPain  = avgPainInCycles(olderCycles,  entries: entries)
        guard let rp = recentPain, let op = olderPain else { return nil }
        let delta = rp - op
        guard abs(delta) >= 2.0 else { return nil }

        let direction = delta < 0 ? "improving" : "getting worse"
        let verb      = delta < 0 ? "down from" : "up from"
        return PatternInsight(
            category: .painTrend,
            title: "Period pain is \(direction)",
            body: "Your average period pain score has gone \(verb) \(String(format: "%.1f", op)) to \(String(format: "%.1f", rp)) over your recent cycles.",
            supportingValue: "\(String(format: "%.0f", op)) → \(String(format: "%.0f", rp)) /10",
            confidence: 0.65
        )
    }

    /// Surfaces the single most common symptom as a simple data point.
    private static func frequentSymptomInsight(entries: [CycleEntry]) -> PatternInsight? {
        guard let (symptom, count) = PredictionEngine.mostFrequentSymptom(in: entries),
              count >= 4 else { return nil }
        return PatternInsight(
            category: .frequentSymptom,
            title: "\(symptom.displayName) is your most logged symptom",
            body: "You've logged \(symptom.displayName.lowercased()) \(count) times. Tracking patterns around it can help predict when it'll appear next.",
            supportingValue: "\(count) times logged",
            confidence: min(1.0, Double(count) / 12.0) * 0.6
        )
    }

    // MARK: - Helpers

    /// Returns the 1-based cycle day for a given date within the provided completed cycles.
    private static func cycleDay(for date: Date, in cycles: [Cycle]) -> (Int, Cycle)? {
        let day = calendar.startOfDay(for: date)
        for cycle in cycles.reversed() {
            if day >= cycle.start {
                let diff = calendar.dateComponents([.day], from: cycle.start, to: day).day ?? 0
                if diff < cycle.length {
                    return (diff + 1, cycle)
                }
            }
        }
        return nil
    }

    private static func energyValue(_ level: EnergyLevel) -> Int {
        switch level {
        case .drained:  return 1
        case .low:      return 2
        case .moderate: return 3
        case .high:     return 4
        case .energized: return 5
        }
    }

    private static func avgPainInCycles(_ cycles: [Cycle], entries: [CycleEntry]) -> Double? {
        var pains: [Int] = []
        for cycle in cycles {
            let end = calendar.date(byAdding: .day, value: cycle.periodLength, to: cycle.start) ?? cycle.start
            let periodEntries = entries.filter {
                let d = calendar.startOfDay(for: $0.date)
                return d >= cycle.start && d < end
            }
            pains += periodEntries.compactMap(\.pain)
        }
        guard !pains.isEmpty else { return nil }
        return Double(pains.reduce(0, +)) / Double(pains.count)
    }
}
