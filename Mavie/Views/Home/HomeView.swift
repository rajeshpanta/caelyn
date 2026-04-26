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
                    onLogPeriod: {},
                    onAddSymptoms: {},
                    onMoodCheckIn: {},
                    onAddNote: {}
                )

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

    private func logMood(_ mood: Mood) {
        if let existing = todayEntry {
            existing.mood = mood
            existing.updatedAt = .now
        } else {
            let entry = CycleEntry(date: today, mood: mood)
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }
}

#Preview("Home — populated") {
    HomeView()
        .modelContainer(Persistence.preview)
}
