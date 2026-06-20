import Foundation

enum HomeCopy {
    static func greeting(for date: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Hey there"
        case 17..<22: return "Good evening"
        default:      return "Late evening"
        }
    }

    static func headlinePrediction(daysUntilPeriod: Int) -> String {
        switch daysUntilPeriod {
        case 0:  return "Your period may start today"
        case 1:  return "Your period may start tomorrow"
        default: return "Your period may start in \(daysUntilPeriod) days"
        }
    }

    static func phaseHeadline(_ phase: CyclePhase, cycleDay: Int, daysUntilPeriod: Int) -> String {
        switch phase {
        case .menstrual:
            return "Day \(cycleDay) of your period"
        case .follicular:
            return "Fresh-energy phase"
        case .ovulation:
            return "Estimated ovulation window"
        case .luteal:
            return headlinePrediction(daysUntilPeriod: daysUntilPeriod)
        case .pms:
            return "PMS may be starting"
        case .unknown:
            return "Welcome to Caelyn"
        }
    }

    static func windowText(_ range: ClosedRange<Date>) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: range.lowerBound)
        let end = formatter.string(from: range.upperBound)
        return "Predicted window: \(start)–\(end)"
    }

    static func comingUpEvents(
        daysUntilPMS: Int,
        daysUntilPeriod: Int,
        daysUntilFertileWindowStart: Int,
        fertileWindow: ClosedRange<Date>?,
        currentPhase: CyclePhase,
        variation: Int = 0
    ) -> [(icon: String, label: String, accent: String)] {
        var events: [(icon: String, label: String, accent: String)] = []

        if currentPhase != .pms && daysUntilPMS > 0 && daysUntilPMS <= 14 {
            events.append((
                icon: "cloud.fill",
                label: "PMS may begin in \(daysUntilPMS) day\(daysUntilPMS == 1 ? "" : "s")",
                accent: "lavender"
            ))
        }
        if currentPhase != .menstrual && daysUntilPeriod >= 0 {
            let base = "Period expected in \(daysUntilPeriod) day\(daysUntilPeriod == 1 ? "" : "s")"
            let label = variation > 1 ? "\(base) (±\(variation) days)" : base
            events.append((icon: "drop.fill", label: label, accent: "rose"))
        }
        let today = Calendar.current.startOfDay(for: .now)
        if currentPhase != .ovulation, let window = fertileWindow,
           daysUntilFertileWindowStart <= 14, window.upperBound >= today {
            let label: String
            if daysUntilFertileWindowStart <= 0 {
                label = "Fertile window: \(shortDateRange(window))"
            } else if daysUntilFertileWindowStart == 1 {
                label = "Fertile window starts tomorrow"
            } else {
                label = "Fertile window in \(daysUntilFertileWindowStart) days (\(shortDateRange(window)))"
            }
            events.append((icon: "sun.max.fill", label: label, accent: "sage"))
        }
        return events
    }

    private static func shortDateRange(_ range: ClosedRange<Date>) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: range.lowerBound))–\(f.string(from: range.upperBound))"
    }

    static func emptyStatePatternMessage(_ confidence: Confidence) -> String {
        switch confidence {
        case .low:    return "Log a few cycles and Caelyn will start surfacing your patterns here."
        case .medium: return "Caelyn is starting to spot patterns — a few more cycles will sharpen them."
        case .high:   return "Your patterns will appear here as you keep logging."
        }
    }
}
