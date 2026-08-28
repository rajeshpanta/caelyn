import Foundation

enum HomeCopy {
    static func greeting(for date: Date = .now) -> String {
        switch hour(from: date) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Hey there"
        case 17..<22: return "Good evening"
        default:      return "Late evening"
        }
    }

    /// The same greeting, with her name when there is one worth using.
    ///
    /// `name` goes through `PersonalName.usable` first, so a nil, blank, or
    /// relay-address name simply falls back to the nameless greeting rather than
    /// producing "Good morning, ". All four time-of-day openers read naturally
    /// with a name appended, which is why this is a suffix and not a rewrite.
    static func greeting(for date: Date = .now, name: String?) -> String {
        let base = greeting(for: date)
        guard let name = PersonalName.usable(name) else { return base }
        return "\(base), \(name)"
    }

    static func greetingEmoji(for date: Date = .now) -> String {
        switch hour(from: date) {
        case 5..<12:  return "\u{2600}\u{FE0F}"
        case 12..<17: return "\u{1F338}"
        case 17..<22: return "\u{1F319}"
        default:      return "\u{2728}"
        }
    }

    /// The hour the greeting should speak from.
    ///
    /// Store capture pins the status bar to 9:41 (`simctl status_bar override`),
    /// but the greeting reads the real clock — so a session recorded at 1am
    /// opened with "Late evening \u{2728}" above a 9:41 status bar, in the one
    /// asset people judge the app by. Under `--screenshot-mode` the greeting
    /// agrees with the pinned clock; every real launch still reads the device.
    private static func hour(from date: Date) -> Int {
        if CommandLine.arguments.contains("--screenshot-mode") { return 9 }
        return Calendar.current.component(.hour, from: date)
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
        variation: Int = 0,
        isLate: Bool = false
    ) -> [(icon: String, label: String, accent: String)] {
        var events: [(icon: String, label: String, accent: String)] = []
        // No real prediction yet (first run / "not sure"), OR the period is overdue:
        // in both cases a forward "Period expected in N days" would contradict the
        // screen — for a late user it fights the late banner (review). Show nothing;
        // HomeComingUp renders its "Nothing on the horizon" empty state (stz-010).
        guard currentPhase != .unknown, !isLate else { return events }

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
