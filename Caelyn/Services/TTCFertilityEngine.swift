import Foundation

/// Computes a daily fertility score (0–100) for TTC (Trying to Conceive) mode.
/// Score is a weighted sum of multiple fertility signals — purely indicative,
/// not medical advice.
enum TTCFertilityEngine {

    struct FertilityResult {
        let score: Int           // 0–100
        let label: String        // "Low", "Moderate", "High", "Peak"
        let signals: [String]    // brief human-readable signal summaries
    }

    static func result(
        todayEntry: CycleEntry?,
        nextPeriodStart: Date?,
        lutealLength: Int = 14
    ) -> FertilityResult {
        var score = 0
        var signals: [String] = []

        // 1. Cycle-day position relative to fertile window
        if let next = nextPeriodStart {
            let fertile = PredictionEngine.fertileWindow(nextPeriodStart: next, lutealLength: lutealLength)
            let ovulationDay = PredictionEngine.ovulationEstimate(nextPeriodStart: next, lutealLength: lutealLength)
            let today = Calendar.current.startOfDay(for: Date.now)
            if Calendar.current.isDate(today, inSameDayAs: ovulationDay) {
                score += 45
                signals.append("Ovulation day · +45")
            } else if fertile.contains(today) {
                score += 30
                signals.append("Fertile window · +30")
            } else {
                score += 5
            }
        } else {
            score += 10  // No prediction but still possible
        }

        // 2. LH strip result
        if let lh = todayEntry?.ovulationTestResult {
            switch lh {
            case .positive: score += 30; signals.append("LH test positive · +30")
            case .lhSurge:  score += 20; signals.append("LH surge detected · +20")
            case .rising:   score += 10; signals.append("LH rising · +10")
            case .negative: score -= 5
            }
        }

        // 3. Cervical mucus
        if let cm = todayEntry?.cervicalMucus {
            switch cm {
            case .eggWhite: score += 20; signals.append("Egg-white mucus (most fertile) · +20")
            case .watery:   score += 12; signals.append("Watery mucus · +12")
            case .creamy:   score += 5
            case .sticky:   score -= 5
            case .dry:      score -= 10
            }
        }

        // 4. BBT — temperature shift indicates post-ovulation
        if let bbt = todayEntry?.basalTemperature {
            if bbt >= 36.7 {
                score -= 15
                signals.append("BBT elevated (post-ovulation) · −15")
            } else if bbt >= 36.3 && bbt < 36.7 {
                score += 8
                signals.append("BBT pre-shift (fertile range) · +8")
            }
        }

        let clamped = max(0, min(100, score))
        let label: String = {
            switch clamped {
            case 75...: return "Peak"
            case 50..<75: return "High"
            case 25..<50: return "Moderate"
            default: return "Low"
            }
        }()
        return FertilityResult(score: clamped, label: label, signals: signals)
    }
}

