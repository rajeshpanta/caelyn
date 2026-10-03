import Foundation

enum DayMarker: Equatable {
    case loggedPeriod(FlowLevel)
    /// In the current period window (most recent flow streak's expected duration)
    /// but the user hasn't logged flow on this day yet. Renders as a soft "fill me in"
    /// state so the user can scan and see which days they missed.
    case activePeriodWindow
    case predictedPeriod
    case pms
    case ovulation
    case empty
}

struct DayState: Equatable {
    let date: Date
    let inMonth: Bool
    let isToday: Bool
    let isFuture: Bool
    let marker: DayMarker
    let hasNote: Bool
    let hasAnyLog: Bool
}

enum CalendarMath {
    /// Every function here takes the calendar it should use, defaulted so no
    /// caller has to change.
    ///
    /// **This was `static let calendar = Calendar.current`, and that one shared
    /// instance was the Phase 1B keyboard-focus bug.** Once `CycleModel.make`
    /// started calling `activePeriodWindow`, the Log tab's body became a hot caller
    /// of this global while the daily form had a text field focused, and typing
    /// into the medication field lost focus mid-entry.
    ///
    /// Isolated by single-variable bisection: reading the same `flow`/`date`
    /// properties through `PredictionEngine` is fine, and an equivalent amount of
    /// unrelated work is fine — only routing entry reads through this shared
    /// `Calendar` reproduced it, and only handing out a fresh value fixed it.
    /// `Calendar` is a value type over a mutating cached reference, so one instance
    /// shared between the Calendar tab and a view being typed into is not something
    /// to hold onto for a small measured saving. A parameter now carries it
    /// instead, so there is no shared instance left to hold onto at all.

    /// 42-day grid (6 weeks × 7 days) covering the visible month plus leading/trailing days.
    static func daysGrid(for month: Date, firstDayOfWeek: Int = 1,
                         calendar: Calendar = .current) -> [Date] {
        var cal = calendar
        cal.firstWeekday = firstDayOfWeek

        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let weekday = cal.component(.weekday, from: startOfMonth)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        let firstCellDate = cal.date(byAdding: .day, value: -leading, to: startOfMonth) ?? startOfMonth

        return (0..<42).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: firstCellDate)
        }
    }

    /// Month label, e.g. "April 2026".
    static func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    /// Weekday symbols ordered by firstDayOfWeek (e.g. ["S","M","T","W","T","F","S"]).
    static func weekdaySymbols(firstDayOfWeek: Int = 1,
                               calendar: Calendar = .current) -> [String] {
        var cal = calendar
        let safeFirst = max(1, min(7, firstDayOfWeek))
        cal.firstWeekday = safeFirst
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let offset = safeFirst - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    /// Compute the marker for a given date based on entries + predictions.
    ///
    /// - Parameter cycle: the authoritative derivation, computed once for the whole
    ///   grid. The calendar used to predict from `profile.averageCycleLength` and
    ///   `profile.lastPeriodStart` while Home predicted from her learned history,
    ///   so the highlighted week could miss Home's predicted window entirely.
    static func dayState(
        for date: Date,
        month: Date,
        entries: [CycleEntry],
        cycle: CycleModel,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> DayState {
        let day = calendar.startOfDay(for: date)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let inMonth = calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isFuture = day > calendar.startOfDay(for: today)

        let dayKey = CivilDay.key(for: day, calendar: calendar)
        let entry = entries.first { $0.dayKey == dayKey }

        // Logged period takes precedence.
        if let flow = entry?.flow {
            return DayState(
                date: day,
                inMonth: inMonth,
                isToday: isToday,
                isFuture: isFuture,
                marker: .loggedPeriod(flow),
                hasNote: entry?.note?.isEmpty == false,
                hasAnyLog: entry?.hasContent ?? false
            )
        }

        // Active period window: if there's a recent flow streak whose expected
        // duration covers `day`, mark it as "expected — fill me in".
        // Only applies to past/today — future days cannot be logged yet.
        if !isFuture,
           let activeWindow = cycle.activePeriodWindow,
           activeWindow.contains(day) {
            return DayState(
                date: day,
                inMonth: inMonth,
                isToday: isToday,
                isFuture: isFuture,
                marker: .activePeriodWindow,
                hasNote: entry?.note?.isEmpty == false,
                hasAnyLog: entry?.hasContent ?? false
            )
        }

        // Predictions need an anchor; without one Caelyn marks nothing.
        var marker: DayMarker = .empty
        if let predictedWindow = cycle.predictedPeriodWindow,
           let pmsRange = cycle.pmsWindow,
           let fertileRange = cycle.fertileWindow {
            if predictedWindow.contains(day) {
                marker = .predictedPeriod
            } else if pmsRange.contains(day) {
                marker = .pms
            } else if fertileRange.contains(day) {
                marker = .ovulation
            }
        }

        return DayState(
            date: day,
            inMonth: inMonth,
            isToday: isToday,
            isFuture: isFuture,
            marker: marker,
            hasNote: entry?.note?.isEmpty == false,
            hasAnyLog: entry?.hasContent ?? false
        )
    }

    /// Returns the date range of the user's *current* period window — the most
    /// recent flow streak's start through `start + periodLength - 1`. Returns nil
    /// if no flow has been logged in the recent past (within periodLength + 2 days).
    static func activePeriodWindow(
        in entries: [CycleEntry],
        periodLength: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> ClosedRange<Date>? {
        let flowDates = entries
            .filter { $0.flow != nil }
            .map { CivilDay.localDate(for: $0.dayKey, calendar: calendar) }
            .filter { $0 <= calendar.startOfDay(for: today) }   // exclude future-dated flow (stz-014)
            .sorted()
        guard let lastFlow = flowDates.last else { return nil }

        // Find the start of the most recent flow streak, forgiving the same
        // one-day hole every other streak reader forgives — "logged Day 1, skipped
        // Day 2, logged Day 3" is one continuous period, not two. The tolerance is
        // `PredictionEngine.sameStreakGapTolerance` so this can never drift out of
        // agreement with cycle reconstruction again.
        var streakStart = lastFlow
        for i in stride(from: flowDates.count - 2, through: 0, by: -1) {
            let prev = flowDates[i]
            let next = flowDates[i + 1]
            let diff = calendar.dateComponents([.day], from: prev, to: next).day ?? 0
            if diff <= PredictionEngine.sameStreakGapTolerance {
                streakStart = prev
            } else {
                break
            }
        }

        // Only call this an "active" window if the streak start is within
        // (periodLength + grace) days of today — past windows are not active.
        let grace = 2
        let daysSinceStart = calendar.dateComponents([.day], from: streakStart, to: calendar.startOfDay(for: today)).day ?? 0
        guard daysSinceStart <= (periodLength - 1) + grace else { return nil }

        let windowEnd = calendar.date(byAdding: .day, value: max(0, periodLength - 1), to: streakStart) ?? streakStart
        return streakStart...windowEnd
    }
}
