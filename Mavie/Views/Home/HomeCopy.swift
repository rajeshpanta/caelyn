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
            return "Welcome to Mavie"
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
        daysUntilOvulation: Int,
        currentPhase: CyclePhase
    ) -> [(icon: String, label: String, accent: String)] {
        var events: [(icon: String, label: String, accent: String)] = []

        if currentPhase != .pms && daysUntilPMS > 0 && daysUntilPMS <= 14 {
            events.append((
                icon: "cloud.fill",
                label: "PMS may begin in \(daysUntilPMS) day\(daysUntilPMS == 1 ? "" : "s")",
                accent: "lavender"
            ))
        }
        if currentPhase != .menstrual && daysUntilPeriod > 0 {
            events.append((
                icon: "drop.fill",
                label: "Period expected in \(daysUntilPeriod) day\(daysUntilPeriod == 1 ? "" : "s")",
                accent: "rose"
            ))
        }
        if currentPhase != .ovulation && daysUntilOvulation > 0 && daysUntilOvulation <= 16 {
            events.append((
                icon: "sun.max.fill",
                label: "Ovulation estimate in \(daysUntilOvulation) day\(daysUntilOvulation == 1 ? "" : "s")",
                accent: "sage"
            ))
        }
        return events
    }

    static func emptyStatePatternMessage(_ confidence: Confidence) -> String {
        switch confidence {
        case .low:    return "Log a few cycles and Mavie will start surfacing your patterns here."
        case .medium: return "Mavie is starting to spot patterns — a few more cycles will sharpen them."
        case .high:   return "Your patterns will appear here as you keep logging."
        }
    }
}
