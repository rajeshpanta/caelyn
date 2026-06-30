import Foundation

/// Detects the post-ovulation **biphasic thermal shift** from a daily temperature
/// series (Apple Watch sleeping wrist temperature, or manually-logged BBT).
///
/// After ovulation, progesterone raises resting body temperature ~0.2–0.5 °C and it
/// stays elevated until the period. The classic "coverline" method flags the first
/// day whose temperature — and the next two days — sit at least 0.2 °C above the
/// average of the prior six days. Ovulation is estimated at the day BEFORE that
/// shift. This is **observational only** — not a contraceptive or medical method,
/// and Caelyn makes no FDA / efficacy claims (int-3).
enum WristTempOvulationEngine {

    struct Result: Equatable {
        /// First day of the sustained temperature rise (nil = no clear shift).
        let shiftDate: Date?
        /// Estimated ovulation day (≈ shiftDate − 1).
        let estimatedOvulation: Date?
        /// 0–1: how clean / large the rise is.
        let confidence: Double

        static let none = Result(shiftDate: nil, estimatedOvulation: nil, confidence: 0)
        var detected: Bool { shiftDate != nil }
    }

    private static let baselineDays = 6
    private static let sustainDays = 2
    private static let riseThreshold = 0.2   // °C above the prior-6-day mean

    /// Detect the biphasic shift in a `(date, °C)` series for a single cycle.
    /// Needs at least baseline + 1 + sustain days of data to be meaningful.
    static func detectShift(in series: [(date: Date, temp: Double)],
                            calendar: Calendar = .current) -> Result {
        // Normalise to one reading per day (latest wins) and sort ascending.
        var byDay: [Date: Double] = [:]
        for point in series { byDay[calendar.startOfDay(for: point.date)] = point.temp }
        let sorted = byDay.map { (date: $0.key, temp: $0.value) }.sorted { $0.date < $1.date }
        guard sorted.count >= baselineDays + 1 + sustainDays else { return .none }

        for i in baselineDays..<(sorted.count - sustainDays) {
            let baseline = sorted[(i - baselineDays)..<i].map(\.temp)
            let mean = baseline.reduce(0, +) / Double(baseline.count)
            let coverline = mean + riseThreshold
            let sustained = (0...sustainDays).allSatisfy { sorted[i + $0].temp >= coverline }
            guard sustained else { continue }

            let shift = sorted[i].date
            let ovulation = calendar.date(byAdding: .day, value: -1, to: shift)
            let lift = sorted[i].temp - mean
            let confidence = min(1.0, max(0.4, lift / 0.4))
            return Result(shiftDate: shift, estimatedOvulation: ovulation, confidence: confidence)
        }
        return .none
    }
}
