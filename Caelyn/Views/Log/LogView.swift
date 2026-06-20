import SwiftUI
import SwiftData

struct LogView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingDeleteConfirm = false

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var isToday: Bool { Calendar.current.isDate(selectedDate, inSameDayAs: today) }

    private var selectedDateLabel: String {
        if isToday { return "Today" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: selectedDate)
    }

    private var cycleDay: Int {
        guard let profile = profiles.first, let lastPeriod = profile.lastPeriodStart else { return 1 }
        return PredictionEngine.currentCycleDay(
            lastPeriodStart: lastPeriod,
            today: selectedDate,
            cycleLength: profile.averageCycleLength
        )
    }

    private var hasEntryOnSelectedDate: Bool {
        entries.contains { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var entryOnSelectedDate: CycleEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                    dateSelectorRow
                    header
                    DailyLogForm(date: selectedDate)
                        .id(selectedDate)
                }
                .padding(.horizontal, CaelynSpacing.lg)
                .padding(.top, CaelynSpacing.md)
                .padding(.bottom, CaelynSpacing.xl)
                .caelynContentWidth()
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Log")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                }
                if !isToday {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                selectedDate = today
                            }
                        }
                        .font(CaelynFont.body.weight(.semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                    }
                }
                if hasEntryOnSelectedDate {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
                        }
                    }
                }
            }
        }
        .confirmationDialog("Delete this log entry?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let entry = entryOnSelectedDate {
                    let dateToClean = entry.date
                    modelContext.delete(entry)
                    modelContext.saveOrLog()
                    Task { await HealthKitSync.deleteFlowIfConnected(on: dateToClean, modelContext: modelContext) }
                    Haptics.selection()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all logged data for \(selectedDateLabel).")
        }
    }

    // MARK: - Date selector

    private var dateSelectorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CaelynSpacing.xs) {
                ForEach(recentDates, id: \.self) { date in
                    datePill(date)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var recentDates: [Date] {
        let cal = Calendar.current
        return (0..<14).compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private func datePill(_ date: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let isTodayDate = cal.isDate(date, inSameDayAs: today)
        let hasEntry = entries.contains { cal.isDate($0.date, inSameDayAs: date) }

        let dayNum = cal.component(.day, from: date)
        let dayAbbrev: String = {
            if isTodayDate { return "Today" }
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f.string(from: date)
        }()

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                selectedDate = date
            }
            Haptics.selection()
        } label: {
            VStack(spacing: 3) {
                Text(dayAbbrev)
                    .font(CaelynFont.caption.weight(isTodayDate ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : CaelynColor.deepPlumText.opacity(0.55))
                Text("\(dayNum)")
                    .font(CaelynFont.headline)
                    .foregroundStyle(isSelected ? .white : CaelynColor.deepPlumText)
                Circle()
                    .fill(hasEntry
                          ? (isSelected ? Color.white.opacity(0.7) : CaelynColor.primaryPlum.opacity(0.55))
                          : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 52)
            .padding(.vertical, CaelynSpacing.sm)
            .background(
                isSelected
                    ? CaelynColor.primaryPlum
                    : (isTodayDate ? CaelynColor.lavender.opacity(0.6) : CaelynColor.cardWhite.opacity(0.7)),
                in: RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous)
                    .stroke(
                        isSelected ? CaelynColor.primaryPlum : CaelynColor.deepPlumText.opacity(0.07),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dayAbbrev) \(dayNum)\(hasEntry ? ", logged" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedDateLabel)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText)
                .contentTransition(.identity)
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: selectedDate)
            HStack(spacing: 6) {
                Text(isToday ? "Today's check-in" : "Past log")
                Text("·")
                Text("Cycle day \(cycleDay)")
            }
            .font(CaelynFont.subheadline)
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))

            if isToday && !hasEntryOnSelectedDate && entries.count < 3 {
                Text("Log even just one thing — every tap teaches Caelyn your pattern.")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.primaryPlum.opacity(0.7))
                    .padding(.top, 2)
            }
        }
    }
}

#Preview {
    LogView()
        .modelContainer(Persistence.preview)
}
