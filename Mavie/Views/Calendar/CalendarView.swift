import SwiftUI

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MavieSpacing.lg) {
                    monthGridSkeleton
                    InsightCard(
                        title: "Coming next",
                        message: "Phase 10 brings the full month grid with logged days, predictions, and per-day editing.",
                        icon: "calendar"
                    )
                }
                .padding(MavieSpacing.lg)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Calendar")
        }
    }

    private var monthGridSkeleton: some View {
        MavieCard {
            VStack(spacing: MavieSpacing.md) {
                HStack {
                    Text(monthLabel)
                        .font(MavieFont.title3)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Spacer()
                }
                weekdayRow
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(1...30, id: \.self) { day in
                        Text("\(day)")
                            .font(MavieFont.callout)
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                }
            }
        }
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                Text(day)
                    .font(MavieFont.caption.weight(.semibold))
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.4))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: .now)
    }
}

#Preview {
    CalendarView()
}
