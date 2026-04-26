import SwiftUI

struct MonthGridView: View {
    let month: Date
    let entries: [CycleEntry]
    let profile: UserProfile?
    let firstDayOfWeek: Int
    let onPrev: () -> Void
    let onNext: () -> Void
    let onDayTap: (Date) -> Void

    private var days: [Date] {
        CalendarMath.daysGrid(for: month, firstDayOfWeek: firstDayOfWeek)
    }

    private var weekdays: [String] {
        CalendarMath.weekdaySymbols(firstDayOfWeek: firstDayOfWeek)
    }

    var body: some View {
        MavieCard {
            VStack(spacing: MavieSpacing.md) {
                navHeader
                weekdayRow
                grid
                legend
            }
        }
    }

    private var navHeader: some View {
        HStack {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(MavieColor.primaryPlum)
                    .background(MavieColor.lavender.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Spacer()
            Text(CalendarMath.monthLabel(for: month))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(MavieColor.deepPlumText)
                .contentTransition(.numericText())
            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(MavieColor.primaryPlum)
                    .background(MavieColor.lavender.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { symbol in
                Text(symbol)
                    .font(MavieFont.caption.weight(.semibold))
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.4))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { date in
                let state = CalendarMath.dayState(
                    for: date,
                    month: month,
                    entries: entries,
                    profile: profile
                )
                DayCell(state: state) {
                    onDayTap(date)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: MavieSpacing.md) {
            legendDot(color: MavieColor.softRose.opacity(0.85), label: "Logged")
            legendDot(color: MavieColor.softRose.opacity(0.25), label: "Predicted")
            legendDot(color: MavieColor.lavender, label: "PMS")
            legendDot(color: MavieColor.sage, label: "Ovulation")
        }
        .padding(.top, 4)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(MavieFont.caption)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
        }
    }
}
