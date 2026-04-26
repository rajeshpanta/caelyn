import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Environment(\.modelContext) private var modelContext

    private var profile: UserProfile? { profiles.first }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var todayEntry: CycleEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var cycles: [Cycle] {
        PredictionEngine.cycles(from: entries)
    }

    private var cycleLength: Int {
        PredictionEngine.averageCycleLength(of: cycles, fallback: profile?.averageCycleLength ?? 28)
    }

    private var periodLength: Int {
        PredictionEngine.averagePeriodLength(of: cycles, fallback: profile?.averagePeriodLength ?? 5)
    }

    private var lastPeriodStart: Date? {
        profile?.lastPeriodStart
    }

    private var cycleDay: Int {
        guard let lastPeriodStart else { return 1 }
        return PredictionEngine.currentCycleDay(
            lastPeriodStart: lastPeriodStart,
            today: today,
            cycleLength: cycleLength
        )
    }

    private var nextStart: Date? {
        guard let lastPeriodStart else { return nil }
        return PredictionEngine.nextPeriodStart(
            lastPeriodStart: lastPeriodStart,
            today: today,
            cycleLength: cycleLength
        )
    }

    private var phase: CyclePhase {
        guard lastPeriodStart != nil else { return .unknown }
        return PredictionEngine.phase(forCycleDay: cycleDay, periodLength: periodLength, cycleLength: cycleLength)
    }

    private var daysUntilPeriod: Int {
        guard let nextStart else { return 0 }
        return PredictionEngine.daysUntil(nextStart, from: today)
    }

    private var daysUntilPMS: Int {
        guard let nextStart else { return 0 }
        let pmsStart = PredictionEngine.pmsWindow(nextPeriodStart: nextStart).lowerBound
        return PredictionEngine.daysUntil(pmsStart, from: today)
    }

    private var daysUntilOvulation: Int {
        guard let nextStart else { return 0 }
        let ovulation = PredictionEngine.ovulationEstimate(nextPeriodStart: nextStart)
        return PredictionEngine.daysUntil(ovulation, from: today)
    }

    private var predictedWindow: ClosedRange<Date>? {
        guard let nextStart else { return nil }
        return PredictionEngine.predictedPeriodWindow(nextPeriodStart: nextStart, periodLength: periodLength)
    }

    private var confidence: Confidence {
        PredictionEngine.confidence(cycleCount: cycles.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MavieSpacing.lg) {
                HomeHeader(
                    greeting: HomeCopy.greeting(),
                    cycleDay: cycleDay,
                    phase: phase
                )

                HomeHeroCard(
                    cycleDay: cycleDay,
                    cycleLength: cycleLength,
                    periodLength: periodLength,
                    phase: phase,
                    daysUntilPeriod: daysUntilPeriod,
                    predictedWindow: predictedWindow
                )

                HomeQuickActions(
                    onLogPeriod: { logPeriodToday() },
                    onAddSymptoms: {},
                    onMoodCheckIn: {},
                    onAddNote: {}
                )

                if isInActivePeriodWindow && todayEntry?.flow == nil {
                    activePeriodPrompt
                }

                HomeMoodCheckIn(
                    selectedMood: todayEntry?.mood,
                    onSelect: logMood
                )

                HomeComingUp(
                    events: HomeCopy.comingUpEvents(
                        daysUntilPMS: daysUntilPMS,
                        daysUntilPeriod: daysUntilPeriod,
                        daysUntilOvulation: daysUntilOvulation,
                        currentPhase: phase
                    )
                )

                HomePatternInsight(
                    confidence: confidence,
                    mostFrequentSymptom: PredictionEngine.mostFrequentSymptom(in: entries)
                )
            }
            .padding(.horizontal, MavieSpacing.lg)
            .padding(.top, MavieSpacing.md)
            .padding(.bottom, MavieSpacing.xl)
        }
        .background(backgroundLayer.ignoresSafeArea())
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                MavieColor.backgroundCream,
                phase.tintBackground.opacity(0.25)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Active period awareness

    private var activePeriodWindow: ClosedRange<Date>? {
        CalendarMath.activePeriodWindow(
            in: entries,
            periodLength: profile?.averagePeriodLength ?? 5,
            today: today
        )
    }

    private var isInActivePeriodWindow: Bool {
        activePeriodWindow?.contains(today) ?? false
    }

    private var dayInPeriod: Int? {
        guard let window = activePeriodWindow else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: window.lowerBound, to: today).day ?? 0
        return diff + 1
    }

    private var isPeriodLate: Bool {
        guard let lastPeriodStart, let nextStart = nextStart else { return false }
        // Late if today >= predicted start AND nothing logged in the active window.
        return today >= nextStart && activePeriodWindow == nil
    }

    private var daysLate: Int {
        guard let lastPeriodStart, let nextStart = nextStart else { return 0 }
        let diff = Calendar.current.dateComponents([.day], from: nextStart, to: today).day ?? 0
        return max(0, diff)
    }

    private var activePeriodPrompt: some View {
        Button {
            logPeriodToday()
        } label: {
            HStack(spacing: MavieSpacing.sm) {
                ZStack {
                    Circle().fill(MavieColor.alertRose.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MavieColor.alertRose)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(activePeriodPromptTitle)
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text("Tap to mark today as a period day.")
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(MavieColor.alertRose)
            }
            .padding(MavieSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous)
                    .fill(MavieColor.blush.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous)
                    .stroke(MavieColor.alertRose.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var activePeriodPromptTitle: String {
        if let day = dayInPeriod {
            return "Day \(day) of your period — log it?"
        }
        return "Did your period start today?"
    }

    /// Quick action: mark today as a Medium-flow period day. If today starts
    /// a new cycle (yesterday had no flow), update the profile's
    /// lastPeriodStart so predictions self-correct immediately.
    private func logPeriodToday() {
        let target: CycleEntry
        if let existing = todayEntry {
            if existing.flow == nil {
                existing.flow = .medium
                existing.updatedAt = .now
            }
            target = existing
        } else {
            target = CycleEntry(date: today, flow: .medium)
            modelContext.insert(target)
        }

        // If yesterday has no flow, this is a cycle start.
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdayHasFlow = entries.contains {
            cal.isDate($0.date, inSameDayAs: yesterday) && $0.flow != nil
        }
        if !yesterdayHasFlow {
            profile?.lastPeriodStart = today
        }

        try? modelContext.save()
        Haptics.success()

        // Sync to HealthKit if connected.
        let snapshot = entries
        Task { await HealthKitSync.syncIfConnected(target, in: snapshot, modelContext: modelContext) }
    }

    private func logMood(_ mood: Mood) {
        let target: CycleEntry
        if let existing = todayEntry {
            existing.mood = mood
            existing.updatedAt = .now
            target = existing
        } else {
            target = CycleEntry(date: today, mood: mood)
            modelContext.insert(target)
        }
        try? modelContext.save()

        // Fire-and-forget HealthKit sync. Mood doesn't sync today, but if the
        // user later updates this entry with flow/symptoms via the log form,
        // the sync hook there will pick it up.
        let snapshot = entries
        Task { await HealthKitSync.syncIfConnected(target, in: snapshot, modelContext: modelContext) }
    }
}

#Preview("Home — populated") {
    HomeView()
        .modelContainer(Persistence.preview)
}
