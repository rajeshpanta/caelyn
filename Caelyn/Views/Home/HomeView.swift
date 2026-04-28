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
            VStack(spacing: CaelynSpacing.lg) {
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

                periodStatePrompt

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
            .padding(.horizontal, CaelynSpacing.lg)
            .padding(.top, CaelynSpacing.md)
            .padding(.bottom, CaelynSpacing.xl)
        }
        .background(backgroundLayer.ignoresSafeArea())
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                CaelynColor.backgroundCream,
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
        guard lastPeriodStart != nil, let next = nextStart else { return false }
        // Late if today is past predicted start AND nothing in active window.
        return today > next && activePeriodWindow == nil
    }

    private var daysLate: Int {
        guard lastPeriodStart != nil, let next = nextStart else { return 0 }
        let diff = Calendar.current.dateComponents([.day], from: next, to: today).day ?? 0
        return max(0, diff)
    }

    @ViewBuilder
    private var periodStatePrompt: some View {
        if isInActivePeriodWindow && todayEntry?.flow == nil {
            activePeriodPrompt
        } else if isPeriodLate, daysLate >= 1 {
            latePeriodPrompt
        }
    }

    private var latePeriodPrompt: some View {
        Button {
            logPeriodToday()
        } label: {
            HStack(spacing: CaelynSpacing.sm) {
                ZStack {
                    Circle().fill(CaelynColor.lavender).frame(width: CaelynIconSize.lg, height: CaelynIconSize.lg)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(latePromptTitle)
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(latePromptSubtitle)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(CaelynColor.alertRose.opacity(0.6))
            }
            .padding(CaelynSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                    .fill(CaelynColor.lavender.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                    .stroke(CaelynColor.primaryPlum.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(latePromptTitle). \(latePromptSubtitle).")
    }

    private var latePromptTitle: String {
        switch daysLate {
        case 0:       return "Your period may start any day now"
        case 1:       return "Your period might be a day late"
        case 2...3:   return "Your period might be \(daysLate) days late"
        case 4...14:  return "Your period is \(daysLate) days late"
        case 15...30: return "It's been \(daysLate) days since your expected period"
        default:      return "Caelyn hasn't seen your period this cycle"
        }
    }

    private var latePromptSubtitle: String {
        if daysLate <= 14 {
            return "Tap to mark today as your first day."
        }
        return "Cycles can vary. Tap when it starts, or update your cycle settings."
    }

    private var activePeriodPrompt: some View {
        Button {
            logPeriodToday()
        } label: {
            HStack(spacing: CaelynSpacing.sm) {
                ZStack {
                    Circle().fill(CaelynColor.alertRose.opacity(0.15)).frame(width: CaelynIconSize.lg, height: CaelynIconSize.lg)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CaelynColor.alertRose)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(activePeriodPromptTitle)
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("Tap to mark today as a period day.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(CaelynColor.alertRose)
            }
            .padding(CaelynSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                    .fill(CaelynColor.blush.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                    .stroke(CaelynColor.alertRose.opacity(0.3), lineWidth: 1)
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

        // Decide whether to update profile.lastPeriodStart to today.
        // We only override if today truly looks like a NEW cycle start —
        // not if the profile already records a recent period start
        // (e.g. user said "my last period was 3 days ago" during onboarding,
        // then taps Log Period today; we shouldn't lose that info).
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdayHasFlow = entries.contains {
            cal.isDate($0.date, inSameDayAs: yesterday) && $0.flow != nil
        }
        if !yesterdayHasFlow {
            let periodLen = profile?.averagePeriodLength ?? 5
            let recentlyStarted: Bool = {
                guard let existing = profile?.lastPeriodStart else { return false }
                let daysSince = cal.dateComponents([.day], from: existing, to: today).day ?? Int.max
                return daysSince >= 0 && daysSince <= periodLen
            }()
            if !recentlyStarted {
                profile?.lastPeriodStart = today
            }
        }

        modelContext.saveOrLog()
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
        modelContext.saveOrLog()

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
