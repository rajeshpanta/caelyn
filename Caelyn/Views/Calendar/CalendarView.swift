import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Query private var profiles: [UserProfile]

    @State private var visibleMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date?
    @State private var swipeDirection: Int = 1  // 1 = forward (→), -1 = backward (←)

    private var profile: UserProfile? { profiles.first }
    private var firstDayOfWeek: Int { profile?.firstDayOfWeek ?? Calendar.current.firstWeekday }
    private var cycles: [Cycle] { PredictionEngine.cycles(from: entries) }

    private var monthTransition: AnyTransition {
        swipeDirection > 0
            ? .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            : .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CaelynSpacing.lg) {
                    MonthGridView(
                        month: visibleMonth,
                        entries: entries,
                        profile: profile,
                        firstDayOfWeek: firstDayOfWeek,
                        cycles: cycles,
                        onPrev: prev,
                        onNext: next,
                        onDayTap: { date in selectedDay = date }
                    )
                    .id(visibleMonth)
                    .transition(monthTransition)

                    MonthSummaryCard(month: visibleMonth, entries: entries)
                        .id(visibleMonth)
                        .transition(monthTransition)
                }
                .padding(.horizontal, CaelynSpacing.lg)
                .padding(.top, CaelynSpacing.md)
                .padding(.bottom, CaelynSpacing.xl)
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !Calendar.current.isDate(visibleMonth, equalTo: .now, toGranularity: .month) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") { jumpToToday() }
                            .font(CaelynFont.body.weight(.semibold))
                            .foregroundStyle(CaelynColor.primaryPlum)
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
        swipeDirection = -1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            visibleMonth = Calendar.current.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
        }
    }

    private func next() {
        swipeDirection = 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            visibleMonth = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
        }
    }

    private func jumpToToday() {
        let isAhead = visibleMonth > Calendar.current.startOfDay(for: .now)
        swipeDirection = isAhead ? -1 : 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
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
