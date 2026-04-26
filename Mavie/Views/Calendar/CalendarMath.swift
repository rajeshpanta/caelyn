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
    static let calendar = Calendar.current

    /// 42-day grid (6 weeks × 7 days) covering the visible month plus leading/trailing days.
    static func daysGrid(for month: Date, firstDayOfWeek: Int = 1) -> [Date] {
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
    static func weekdaySymbols(firstDayOfWeek: Int = 1) -> [String] {
        var cal = calendar
        cal.firstWeekday = firstDayOfWeek
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let offset = firstDayOfWeek - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    /// Compute the marker for a given date based on entries + predictions.
    static func dayState(
        for date: Date,
        month: Date,
        entries: [CycleEntry],
        profile: UserProfile?,
        today: Date = .now
    ) -> DayState {
        let day = calendar.startOfDay(for: date)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let inMonth = calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isFuture = day > calendar.startOfDay(for: today)

        let entry = entries.first { calendar.isDate($0.date, inSameDayAs: day) }

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
        let periodLength = profile?.averagePeriodLength ?? 5
        if let activeWindow = activePeriodWindow(in: entries, periodLength: periodLength, today: today),
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

        // Future predictions require a profile + last period.
        var marker: DayMarker = .empty
        if let profile, let last = profile.lastPeriodStart {
            let cycleLength = profile.averageCycleLength
            let nextStart = PredictionEngine.nextPeriodStart(
                lastPeriodStart: last,
                today: today,
                cycleLength: cycleLength
            )
            let predictedWindow = PredictionEngine.predictedPeriodWindow(
                nextPeriodStart: nextStart,
                periodLength: periodLength
            )
            let pmsRange = PredictionEngine.pmsWindow(nextPeriodStart: nextStart)
            let ovulation = PredictionEngine.ovulationEstimate(nextPeriodStart: nextStart)
            let ovulationStart = calendar.date(byAdding: .day, value: -1, to: ovulation) ?? ovulation
            let ovulationEnd = calendar.date(byAdding: .day, value: 1, to: ovulation) ?? ovulation

            if predictedWindow.contains(day) {
                marker = .predictedPeriod
            } else if pmsRange.contains(day) {
                marker = .pms
            } else if (ovulationStart...ovulationEnd).contains(day) {
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
        today: Date = .now
    ) -> ClosedRange<Date>? {
        let flowDates = entries
            .filter { $0.flow != nil }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
        guard !flowDates.isEmpty else { return nil }

        // Find the start of the most recent flow streak. We tolerate gaps of
        // up to 1 unlogged day (diff <= 2) so that "logged Day 1, skipped Day 2,
        // logged Day 3" is treated as one continuous period — not two streaks.
        // This is the difference between forgiving the user and punishing them.
        var streakStart = flowDates.last!
        for i in stride(from: flowDates.count - 2, through: 0, by: -1) {
            let prev = flowDates[i]
            let next = flowDates[i + 1]
            let diff = calendar.dateComponents([.day], from: prev, to: next).day ?? 0
            if diff <= 2 {
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
