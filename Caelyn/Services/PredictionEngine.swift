import Foundation

enum PredictionEngine {
    private static var calendar: Calendar { Calendar.current }

    /// Reconstruct cycles from logged entries.
    /// A cycle starts at the first day of a flow streak and runs until the day before
    /// the next flow streak begins. The most recent (in-progress) cycle has length 0
    /// and is excluded from this list — use `currentCycleDay` for the live cycle.
    static func cycles(from entries: [CycleEntry], today: Date = .now) -> [Cycle] {
        // Exclude future-dated flow: a flow tap dated ahead of today must not be
        // treated as a period start, or it fabricates a huge phantom cycle that
        // skews every average and can false-trigger the irregular banner (stz-014).
        let cutoff = calendar.startOfDay(for: today)
        let dayStarts: [Date] = entries
            .filter { $0.flow != nil }
            .map { calendar.startOfDay(for: $0.date) }
            .filter { $0 <= cutoff }
            .sorted()

        guard !dayStarts.isEmpty else { return [] }

        var periodStarts: [Date] = [dayStarts[0]]
        for i in 1..<dayStarts.count {
            let gap = calendar.dateComponents([.day], from: dayStarts[i - 1], to: dayStarts[i]).day ?? 0
            if gap > 1 {
                periodStarts.append(dayStarts[i])
            }
        }

        guard periodStarts.count >= 2 else { return [] }

        let daySet = Set(dayStarts)
        var cycles: [Cycle] = []
        for i in 0..<(periodStarts.count - 1) {
            let start = periodStarts[i]
            let nextStart = periodStarts[i + 1]
            let length = calendar.dateComponents([.day], from: start, to: nextStart).day ?? 0
            let periodLength = consecutiveFlowDays(from: start, in: daySet)
            cycles.append(Cycle(start: start, length: length, periodLength: periodLength))
        }
        return cycles
    }

    private static func consecutiveFlowDays(from start: Date, in daySet: Set<Date>) -> Int {
        var count = 0
        var cursor = start
        while daySet.contains(cursor) {
            count += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return count
    }

    /// Recency-weighted mean of recent cycle lengths. More recent cycles count more
    /// (decay factor 0.85 per step back), so the prediction self-corrects faster
    /// when the user's cycle changes. Falls back to user-entered value when fewer
    /// than 2 cycles logged.
    static func averageCycleLength(of cycles: [Cycle], fallback: Int) -> Int {
        guard cycles.count >= 2 else { return clampCycleLength(fallback) }
        let recent = Array(cycles.suffix(6))
        return clampCycleLength(weightedMean(recent.map(\.length)))
    }

    static func averagePeriodLength(of cycles: [Cycle], fallback: Int) -> Int {
        guard cycles.count >= 2 else { return clampPeriodLength(fallback) }
        let recent = Array(cycles.suffix(6))
        return clampPeriodLength(weightedMean(recent.map(\.periodLength)))
    }

    /// Realistic bounds (mirroring the Settings sliders) so noisy or sparse logging
    /// can't yield impossible predictions like "Day 7 of 3" (int-1).
    static func clampCycleLength(_ v: Int) -> Int { min(45, max(18, v)) }
    static func clampPeriodLength(_ v: Int) -> Int { min(12, max(1, v)) }

    /// Variation: half the spread of recent cycle lengths (±N days), rounded so a
    /// 15-day spread reads ±8, not ±7 (int-1).
    static func cycleLengthVariation(of cycles: [Cycle]) -> Int {
        guard cycles.count >= 2 else { return 0 }
        let lengths = cycles.suffix(6).map(\.length)
        guard let minLen = lengths.min(), let maxLen = lengths.max() else { return 0 }
        return Int((Double(maxLen - minLen) / 2.0).rounded())
    }

    /// Exponentially-weighted mean: newest value has weight 1.0, each prior step
    /// decays by 0.85. Values are ordered oldest → newest (suffix order).
    private static func weightedMean(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let decay = 0.85
        var weightedSum = 0.0
        var totalWeight = 0.0
        for (i, value) in values.enumerated() {
            let weight = pow(decay, Double(values.count - 1 - i))
            weightedSum += Double(value) * weight
            totalWeight += weight
        }
        return Int((weightedSum / totalWeight).rounded())
    }

    /// Cycle day (1-indexed) computed by wrapping at cycleLength.
    static func currentCycleDay(lastPeriodStart: Date, today: Date = .now, cycleLength: Int) -> Int {
        let lp = calendar.startOfDay(for: lastPeriodStart)
        let t = calendar.startOfDay(for: today)
        let days = calendar.dateComponents([.day], from: lp, to: t).day ?? 0
        let safeLen = max(cycleLength, 1)
        return ((max(0, days)) % safeLen) + 1
    }

    /// Predicted next period start (today projected into the next cycle).
    static func nextPeriodStart(lastPeriodStart: Date, today: Date = .now, cycleLength: Int) -> Date {
        let lp = calendar.startOfDay(for: lastPeriodStart)
        let t = calendar.startOfDay(for: today)
        let safeLen = max(cycleLength, 1)
        guard var nextStart = calendar.date(byAdding: .day, value: safeLen, to: lp) else { return t }
        var iterations = 0
        while nextStart < t {
            guard let next = calendar.date(byAdding: .day, value: safeLen, to: nextStart) else { break }
            nextStart = next
            iterations += 1
            if iterations > 3650 { break }  // safety cap: ~10 years of daily cycles
        }
        return nextStart
    }

    /// The *un-rolled* expected period start: lastPeriodStart + one cycle.
    /// Unlike `nextPeriodStart`, this is NOT advanced past today — so it can be in
    /// the past, which is exactly what late-period detection needs (stz-009).
    static func expectedPeriodStart(lastPeriodStart: Date, cycleLength: Int) -> Date {
        let lp = calendar.startOfDay(for: lastPeriodStart)
        let safeLen = max(cycleLength, 1)
        return calendar.date(byAdding: .day, value: safeLen, to: lp) ?? lp
    }

    /// Start of the most recent flow streak on or before `today` — used to recover
    /// the period anchor after an entry is removed, instead of blindly clearing it.
    /// Tolerates 1-day gaps (matches activePeriodWindow). nil if no flow remains.
    static func mostRecentPeriodStart(from entries: [CycleEntry], today: Date = .now) -> Date? {
        let cutoff = calendar.startOfDay(for: today)
        let dayStarts = entries
            .filter { $0.flow != nil }
            .map { calendar.startOfDay(for: $0.date) }
            .filter { $0 <= cutoff }
            .sorted()
        guard let last = dayStarts.last else { return nil }
        var streakStart = last
        for i in stride(from: dayStarts.count - 2, through: 0, by: -1) {
            let gap = calendar.dateComponents([.day], from: dayStarts[i], to: dayStarts[i + 1]).day ?? 0
            if gap <= 2 { streakStart = dayStarts[i] } else { break }
        }
        return streakStart
    }

    /// How many days past the expected start the period is, or 0 if not late.
    static func daysLate(lastPeriodStart: Date, today: Date = .now, cycleLength: Int) -> Int {
        let expected = expectedPeriodStart(lastPeriodStart: lastPeriodStart, cycleLength: cycleLength)
        let t = calendar.startOfDay(for: today)
        return max(0, calendar.dateComponents([.day], from: expected, to: t).day ?? 0)
    }

    /// Predicted period window: nextStart through nextStart + (periodLength - 1).
    static func predictedPeriodWindow(nextPeriodStart: Date, periodLength: Int) -> ClosedRange<Date> {
        let safeLen = max(periodLength, 1)
        let end = calendar.date(byAdding: .day, value: safeLen - 1, to: nextPeriodStart) ?? nextPeriodStart
        return nextPeriodStart...end
    }

    /// Estimated ovulation day: nextStart − lutealLength. Defaults to the standard
    /// 14-day luteal model; pass `learnedLutealLength(...)` to personalise (int-1).
    static func ovulationEstimate(nextPeriodStart: Date, lutealLength: Int = 14) -> Date {
        calendar.date(byAdding: .day, value: -max(1, lutealLength), to: nextPeriodStart) ?? nextPeriodStart
    }

    /// Fertile window: the 5-day window where conception is most likely.
    /// Sperm survive up to 5 days; the egg lives ~12-24 hours post-ovulation.
    /// Window spans ovulation-day-4 through ovulation-day+1 (peak = ovulation day).
    static func fertileWindow(nextPeriodStart: Date, lutealLength: Int = 14) -> ClosedRange<Date> {
        let ovulation = ovulationEstimate(nextPeriodStart: nextPeriodStart, lutealLength: lutealLength)
        let start = calendar.date(byAdding: .day, value: -4, to: ovulation) ?? ovulation
        let end   = calendar.date(byAdding: .day, value: 1,  to: ovulation) ?? ovulation
        return start...end
    }

    /// Per-user luteal-phase length learned from confirmed ovulation signals (LH
    /// positive / surge): days from the peak LH day to the next period start,
    /// averaged over cycles. Returns nil — so callers use the 14-day default —
    /// until ≥3 cycles carry a usable signal. Clamped to a physiologic 9–17 days (int-1).
    static func learnedLutealLength(entries: [CycleEntry], cycles: [Cycle]) -> Int? {
        var lengths: [Int] = []
        for cycle in cycles {
            guard let cycleEnd = calendar.date(byAdding: .day, value: cycle.length, to: cycle.start) else { continue }
            let markers = entries.compactMap { e -> Date? in
                let d = calendar.startOfDay(for: e.date)
                guard d >= cycle.start && d < cycleEnd else { return nil }
                guard e.ovulationTestResult == .positive || e.ovulationTestResult == .lhSurge else { return nil }
                return d
            }.sorted()
            if let ovulation = markers.last {
                let luteal = calendar.dateComponents([.day], from: ovulation, to: cycleEnd).day ?? 0
                if luteal >= 9 && luteal <= 17 { lengths.append(luteal) }
            }
        }
        guard lengths.count >= 3 else { return nil }
        return Int((Double(lengths.reduce(0, +)) / Double(lengths.count)).rounded())
    }

    /// PMS window ending the day before the predicted period.
    /// `daysBefore` defaults to 5; pass `adaptivePmsDaysBefore()` to personalise.
    static func pmsWindow(nextPeriodStart: Date, daysBefore: Int = 5) -> ClosedRange<Date> {
        let end = calendar.date(byAdding: .day, value: -1, to: nextPeriodStart) ?? nextPeriodStart
        let start = calendar.date(byAdding: .day, value: -daysBefore, to: nextPeriodStart) ?? end
        return start...end
    }

    /// Returns the average number of days before the period start at which PMS
    /// symptoms / moods first appear, derived from actual logged data. Returns nil
    /// when fewer than 3 cycles have qualifying markers (fallback to the default 5).
    static func adaptivePmsDaysBefore(entries: [CycleEntry], cycles: [Cycle]) -> Int? {
        let pmsSymptoms: Set<Symptom> = [.bloating, .cravings, .tenderBreasts, .fatigue, .acne, .cramps]
        let pmsMoods: Set<Mood>       = [.anxious, .irritable, .moody, .sad, .sensitive, .lowEnergy]

        var onsets: [Int] = []
        for cycle in cycles {
            guard let windowStart = calendar.date(byAdding: .day, value: -14, to: cycle.start) else { continue }
            let periodDay = calendar.startOfDay(for: cycle.start)

            let windowEntries = entries.filter {
                let d = calendar.startOfDay(for: $0.date)
                return d >= windowStart && d < periodDay
            }

            // Find the *earliest* PMS marker in the pre-period window.
            let pmsEntries = windowEntries.filter { entry in
                let hasMood    = entry.mood.map { pmsMoods.contains($0) } ?? false
                let hasSymptom = entry.symptoms.contains { pmsSymptoms.contains($0) }
                return hasMood || hasSymptom
            }

            if let earliest = pmsEntries.map({ calendar.startOfDay(for: $0.date) }).min() {
                let daysUntil = calendar.dateComponents([.day], from: earliest, to: periodDay).day ?? 0
                if daysUntil > 0 { onsets.append(daysUntil) }
            }
        }

        guard onsets.count >= 3 else { return nil }
        let avg = Int((Double(onsets.reduce(0, +)) / Double(onsets.count)).rounded())   // round, not truncate (int-1)
        return max(2, min(14, avg))
    }

    /// Phase classification for a cycle day (1-indexed).
    ///
    /// Uses the standard 14-day luteal-phase model: ovulation is estimated at
    /// `cycleLength − 14`. The model only produces meaningful phases when
    /// ovulation falls *after* the menstrual window — i.e. when
    /// `cycleLength > periodLength + 14`. For shorter cycles (polymenorrhea,
    /// or junk data) we report `.menstrual` while the user is bleeding and
    /// `.unknown` for the remainder, instead of returning overlapping/garbled
    /// phase labels that aren't medically meaningful.
    static func phase(forCycleDay day: Int, periodLength: Int, cycleLength: Int, lutealLength: Int = 14) -> CyclePhase {
        guard cycleLength > 0 else { return .unknown }
        let safePeriod = max(1, periodLength)
        let ovulation = cycleLength - max(1, lutealLength)

        guard ovulation > safePeriod else {
            return (day >= 1 && day <= safePeriod) ? .menstrual : .unknown
        }

        let pmsStart = max(1, cycleLength - 4)

        if day >= 1 && day <= safePeriod { return .menstrual }
        if day >= pmsStart && day <= cycleLength { return .pms }
        if abs(day - ovulation) <= 1 { return .ovulation }
        if day < ovulation { return .follicular }
        return .luteal
    }

    static func confidence(cycleCount: Int) -> Confidence {
        switch cycleCount {
        case 0..<3:  return .low
        case 3..<6:  return .medium
        default:     return .high
        }
    }

    /// Days from `today` to `target` (truncated to start-of-day, never negative for future dates).
    static func daysUntil(_ target: Date, from today: Date = .now) -> Int {
        let t = calendar.startOfDay(for: today)
        let target = calendar.startOfDay(for: target)
        return max(0, calendar.dateComponents([.day], from: t, to: target).day ?? 0)
    }

    /// Most-frequent symptom across the given entries (for the pattern card).
    static func mostFrequentSymptom(in entries: [CycleEntry]) -> (Symptom, Int)? {
        var counts: [Symptom: Int] = [:]
        for entry in entries {
            for s in entry.symptoms {
                counts[s, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })
    }

    /// Determines whether logged cycle data suggests irregular cycles.
    /// Requires at least 3 completed cycles for any determination.
    static func irregularCycleStatus(from cycles: [Cycle]) -> IrregularCycleStatus {
        guard cycles.count >= 3 else { return .insufficient }

        let lengths = cycles.map(\.length)
        let avg = Double(lengths.reduce(0, +)) / Double(lengths.count)
        let variation = cycleLengthVariation(of: cycles)

        // Any cycle longer than 45 days → skipped period
        if lengths.contains(where: { $0 > 45 }) {
            return .irregular(reason: .skippedPeriods)
        }

        // High variation (> 7 days)
        if variation > 7 {
            return .irregular(reason: .highVariation)
        }

        // Consistently long cycles (avg > 35 days)
        if avg > 35 {
            return .irregular(reason: .longCycles)
        }

        // Consistently short cycles (avg < 21 days)
        if avg < 21 {
            return .irregular(reason: .shortCycles)
        }

        // Progressive shift (requires ≥6 cycles): recent avg differs from older avg by >7 days
        if cycles.count >= 6 {
            let recent = cycles.suffix(3).map(\.length)
            let older  = cycles.dropLast(3).suffix(3).map(\.length)
            let rAvg   = Double(recent.reduce(0, +)) / 3.0
            let oAvg   = Double(older.reduce(0, +)) / 3.0
            if abs(rAvg - oAvg) >= 7 {
                return .irregular(reason: .increasingShift)
            }
        }

        return .regular
    }
}
