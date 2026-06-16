import SwiftUI

struct YearViewSection: View {
    let entries: [CycleEntry]
    let profile: UserProfile?
    let isPro: Bool
    var onUpgrade: () -> Void = {}

    private var cal: Calendar { Calendar.current }
    private var firstDayOfWeek: Int { profile?.firstDayOfWeek ?? cal.firstWeekday }

    private var monthsToShow: [Date] {
        let today = cal.startOfDay(for: .now)
        return (0..<12).reversed().compactMap { offset in
            cal.date(byAdding: .month, value: -offset, to: today)
                .flatMap { cal.date(from: cal.dateComponents([.year, .month], from: $0)) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(
                title: "Year in Review",
                subtitle: "Last 12 months"
            )

            let months = isPro ? monthsToShow : Array(monthsToShow.suffix(3))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CaelynSpacing.md) {
                ForEach(months, id: \.self) { month in
                    MiniMonthView(month: month, entries: entries, profile: profile, firstDayOfWeek: firstDayOfWeek)
                }
            }

            if !isPro {
                Button(action: onUpgrade) {
                    CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.lavender.opacity(0.45)) {
                        HStack(spacing: CaelynSpacing.sm) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(CaelynColor.primaryPlum)
                            Text("Unlock your full year with Pro")
                                .font(CaelynFont.callout.weight(.semibold))
                                .foregroundStyle(CaelynColor.primaryPlum)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(CaelynColor.primaryPlum.opacity(0.6))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Mini month grid

private struct MiniMonthView: View {
    let month: Date
    let entries: [CycleEntry]
    let profile: UserProfile?
    let firstDayOfWeek: Int

    private let dotSize: CGFloat = 7
    private let spacing: CGFloat = 3
    private var cal: Calendar { Calendar.current }

    private var days: [Date] { CalendarMath.daysGrid(for: month, firstDayOfWeek: firstDayOfWeek) }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: month)
    }

    private var entryMap: [Date: CycleEntry] {
        Dictionary(
            entries.compactMap { entry -> (Date, CycleEntry)? in
                let d = cal.startOfDay(for: entry.date)
                return (d, entry)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var nextPeriodStart: Date? {
        guard let last = profile?.lastPeriodStart else { return nil }
        return PredictionEngine.nextPeriodStart(
            lastPeriodStart: last,
            today: .now,
            cycleLength: profile?.averageCycleLength ?? 28
        )
    }

    var body: some View {
        CaelynCard(padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(monthLabel)
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(dotSize), spacing: spacing), count: 7),
                    spacing: spacing
                ) {
                    ForEach(days, id: \.self) { date in
                        dayDot(for: date)
                    }
                }
            }
        }
    }

    private func dayDot(for date: Date) -> some View {
        let day = cal.startOfDay(for: date)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let inMonth = cal.isDate(day, equalTo: monthStart, toGranularity: .month)
        let color = dotColor(for: day, inMonth: inMonth)

        return Rectangle()
            .fill(color)
            .frame(width: dotSize, height: dotSize)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }

    private func dotColor(for day: Date, inMonth: Bool) -> Color {
        guard inMonth else { return .clear }

        let entry = entryMap[day]

        // Logged period — strongest signal
        if entry?.flow != nil { return CaelynColor.softRose.opacity(0.9) }

        // Has any log
        let hasLog = entry?.hasContent ?? false

        // Predicted future events
        if let next = nextPeriodStart {
            let periodLength = profile?.averagePeriodLength ?? 5
            let predicted = PredictionEngine.predictedPeriodWindow(nextPeriodStart: next, periodLength: periodLength)
            let pms = PredictionEngine.pmsWindow(nextPeriodStart: next)
            let fertile = PredictionEngine.fertileWindow(nextPeriodStart: next)

            if predicted.contains(day) { return CaelynColor.softRose.opacity(0.4) }
            if pms.contains(day)       { return CaelynColor.lavender.opacity(0.7) }
            if fertile.contains(day)   { return CaelynColor.sage.opacity(0.7) }
        }

        if hasLog { return CaelynColor.warmSand.opacity(0.6) }
        return CaelynColor.deepPlumText.opacity(0.07)
    }
}
