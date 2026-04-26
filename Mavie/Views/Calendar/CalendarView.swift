import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Query private var profiles: [UserProfile]

    @State private var visibleMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date?

    private var profile: UserProfile? { profiles.first }
    private var firstDayOfWeek: Int { profile?.firstDayOfWeek ?? Calendar.current.firstWeekday }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MavieSpacing.lg) {
                    MonthGridView(
                        month: visibleMonth,
                        entries: entries,
                        profile: profile,
                        firstDayOfWeek: firstDayOfWeek,
                        onPrev: prev,
                        onNext: next,
                        onDayTap: { date in selectedDay = date }
                    )

                    MonthSummaryCard(month: visibleMonth, entries: entries)
                }
                .padding(.horizontal, MavieSpacing.lg)
                .padding(.top, MavieSpacing.md)
                .padding(.bottom, MavieSpacing.xl)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !Calendar.current.isDate(visibleMonth, equalTo: .now, toGranularity: .month) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") { jumpToToday() }
                            .font(MavieFont.body.weight(.semibold))
                            .foregroundStyle(MavieColor.primaryPlum)
                    }
                }
            }
        }
        .sheet(item: Binding<DateID?>(
            get: { selectedDay.map { DateID(date: $0) } },
            set: { selectedDay = $0?.date }
        )) { wrapper in
            DayDetailSheet(
                date: wrapper.date,
                isPresented: Binding(
                    get: { selectedDay != nil },
                    set: { if !$0 { selectedDay = nil } }
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func prev() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            visibleMonth = Calendar.current.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
        }
    }

    private func next() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            visibleMonth = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
        }
    }

    private func jumpToToday() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            visibleMonth = Calendar.current.startOfDay(for: .now)
        }
    }
}

private struct DateID: Identifiable {
    let date: Date
    var id: Date { date }
}

#Preview {
    CalendarView()
        .modelContainer(Persistence.preview)
}
