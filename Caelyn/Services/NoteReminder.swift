import Foundation

/// A gentle, optional reminder attached to a day's note (note-to-self). Its
/// timing can be a fixed date OR **cycle-relative** — the one thing only a period
/// app can do ("before my next period", "when my period starts"). Cycle-relative
/// reminders are re-resolved against the current prediction on every sync, so they
/// follow her cycle as it shifts. Fires ONCE, gently, and respects quiet hours +
/// private-notification settings — never a nag, never a to-do app.
enum NoteReminderRule: String, CaseIterable, Identifiable {
    case date
    case beforePeriod
    case atPeriod

    var id: String { rawValue }

    var label: String {
        switch self {
        case .date:         return "On a date"
        case .beforePeriod: return "Before my next period"
        case .atPeriod:     return "When my period starts"
        }
    }

    /// How the resolved reminder reads on the day's log, e.g. "Reminds you 2 days
    /// before your next period."
    var picked: String {
        switch self {
        case .date:         return "Reminds you on the date you chose."
        case .beforePeriod: return "Reminds you \(NoteReminder.daysBeforePeriod) days before your next period."
        case .atPeriod:     return "Reminds you when your next period is predicted to start."
        }
    }
}

@MainActor
enum NoteReminder {
    nonisolated static let defaultHour = 9
    nonisolated static let daysBeforePeriod = 2

    /// Resolve the concrete fire date for a rule (pure + testable). Returns nil
    /// when there's nothing to schedule (no prediction yet, or the moment passed).
    static func fireDate(
        rule: NoteReminderRule,
        chosenDate: Date?,
        nextPeriodStart: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        switch rule {
        case .date:
            guard let chosenDate, chosenDate > now else { return nil }
            return chosenDate
        case .beforePeriod:
            guard let next = nextPeriodStart else { return nil }
            let day = calendar.date(byAdding: .day, value: -daysBeforePeriod, to: next) ?? next
            // If "2 days before" is already past (period is imminent), fall back to
            // the period start day itself so the reminder still lands.
            return NotificationService.scheduledFireDate(on: day, hour: defaultHour, minute: 0, now: now)
                ?? NotificationService.scheduledFireDate(on: next, hour: defaultHour, minute: 0, now: now)
        case .atPeriod:
            guard let next = nextPeriodStart else { return nil }
            return NotificationService.scheduledFireDate(on: next, hour: defaultHour, minute: 0, now: now)
        }
    }
}
