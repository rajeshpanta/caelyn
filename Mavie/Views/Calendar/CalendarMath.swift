import Foundation

enum DayMarker: Equatable {
    case loggedPeriod(FlowLevel)
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

        // Predictions only apply to future-or-today dates and require a profile + last period.
        var marker: DayMarker = .empty
        if let profile, let last = profile.lastPeriodStart {
            let cycleLength = profile.averageCycleLength
            let periodLength = profile.averagePeriodLength
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
}
