import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var showingLogSheet = false
    @State private var showingPeriodStartSheet = false
    @State private var periodStartDraft: Date = .now

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

    private var adaptivePmsDays: Int {
        PredictionEngine.adaptivePmsDaysBefore(entries: entries, cycles: cycles) ?? 5
    }

    private var irregularStatus: IrregularCycleStatus {
        PredictionEngine.irregularCycleStatus(from: cycles)
    }

    private var daysUntilPMS: Int {
        guard let nextStart else { return 0 }
        let pmsStart = PredictionEngine.pmsWindow(nextPeriodStart: nextStart, daysBefore: adaptivePmsDays).lowerBound
        return PredictionEngine.daysUntil(pmsStart, from: today)
    }

    private var daysUntilOvulation: Int {
        guard let nextStart else { return 0 }
        let ovulation = PredictionEngine.ovulationEstimate(nextPeriodStart: nextStart)
        return PredictionEngine.daysUntil(ovulation, from: today)
    }

    private var fertileWindow: ClosedRange<Date>? {
        guard let nextStart else { return nil }
        return PredictionEngine.fertileWindow(nextPeriodStart: nextStart)
    }

    private var daysUntilFertileWindowStart: Int {
        guard let window = fertileWindow else { return 0 }
        return PredictionEngine.daysUntil(window.lowerBound, from: today)
    }

    private var predictedWindow: ClosedRange<Date>? {
        guard let nextStart else { return nil }
        return PredictionEngine.predictedPeriodWindow(nextPeriodStart: nextStart, periodLength: periodLength)
    }

    private var confidence: Confidence {
        PredictionEngine.confidence(cycleCount: cycles.count)
    }

    private var ttcResult: TTCFertilityEngine.FertilityResult {
        TTCFertilityEngine.result(
            todayEntry: todayEntry,
            cycleDay: cycleDay,
            nextPeriodStart: nextStart,
            cycleLength: cycleLength
        )
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
                    predictedWindow: predictedWindow,
                    variation: PredictionEngine.cycleLengthVariation(of: cycles),
                    confidence: confidence
                )

                HomeQuickActions(
                    onLogPeriod: { logPeriodToday() },
                    onAddSymptoms: { showingLogSheet = true },
                    onMoodCheckIn: { showingLogSheet = true },
                    onAddNote:     { showingLogSheet = true }
                )
                .sheet(isPresented: $showingLogSheet) {
                    NavigationStack {
                        ScrollView {
                            DailyLogForm(date: today)
                                .padding(CaelynSpacing.lg)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .background(CaelynColor.backgroundCream.ignoresSafeArea())
                        .navigationTitle("Today's Log")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showingLogSheet = false }
                                    .font(CaelynFont.body.weight(.semibold))
                                    .foregroundStyle(CaelynColor.primaryPlum)
                            }
                        }
                    }
                    .presentationDetents([.large])
                }

                HomeStreakCard(
                    streak: CycleAnalytics.loggingStreak(in: entries, today: today),
                    recentDays: CycleAnalytics.recentDayStates(in: entries, today: today)
                )

                periodStatePrompt

                periodStartEditRow

                irregularModeBanner

                if profile?.ttcEnabled == true {
                    TTCDashboardCard(result: ttcResult, nextPeriodStart: nextStart)
                }

                if profile?.pregnancyEnabled == true, let due = profile?.pregnancyDueDate {
                    PregnancyModeCard(dueDate: due)
                }

                if profile?.postpartumEnabled == true, let birth = profile?.postpartumBirthDate {
                    PostpartumModeCard(birthDate: birth)
                }

                HomeMoodCheckIn(
                    selectedMood: todayEntry?.mood,
                    onSelect: logMood
                )

                HomeComingUp(
                    events: HomeCopy.comingUpEvents(
                        daysUntilPMS: daysUntilPMS,
                        daysUntilPeriod: daysUntilPeriod,
                        daysUntilFertileWindowStart: daysUntilFertileWindowStart,
                        fertileWindow: fertileWindow,
                        currentPhase: phase,
                        variation: PredictionEngine.cycleLengthVariation(of: cycles)
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
            .caelynContentWidth()
            .frame(maxWidth: .infinity)
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
        .accessibilityLabel("\(activePeriodPromptTitle). Tap to mark today as a period day.")
    }

    private var activePeriodPromptTitle: String {
        if let day = dayInPeriod {
            return "Day \(day) of your period — log it?"
        }
        return "Did your period start today?"
    }

    // MARK: - Period start edit row

    @ViewBuilder
    private var periodStartEditRow: some View {
        if let start = profile?.lastPeriodStart, isInActivePeriodWindow {
            let fmt: DateFormatter = {
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                return f
            }()
            let label = Calendar.current.isDateInToday(start) ? "today" : fmt.string(from: start)
            Button {
                periodStartDraft = start
                showingPeriodStartSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CaelynColor.primaryPlum.opacity(0.65))
                    Text("Period started \(label) · Change date")
                        .font(CaelynFont.caption.weight(.medium))
                        .foregroundStyle(CaelynColor.primaryPlum.opacity(0.75))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CaelynColor.primaryPlum.opacity(0.35))
                }
                .padding(.horizontal, CaelynSpacing.md)
                .padding(.vertical, CaelynSpacing.sm)
                .background(CaelynColor.lavender.opacity(0.45), in: RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingPeriodStartSheet) {
                periodStartSheet
            }
        }
    }

    private var periodStartSheet: some View {
        NavigationStack {
            VStack(spacing: CaelynSpacing.lg) {
                DatePicker(
                    "Period start date",
                    selection: $periodStartDraft,
                    in: ...today,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(CaelynColor.primaryPlum)
                .padding(.horizontal, CaelynSpacing.md)

                Button(role: .destructive) {
                    removePeriodLog()
                    showingPeriodStartSheet = false
                } label: {
                    Label("Remove period log", systemImage: "trash")
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.alertRose)
                        .frame(maxWidth: .infinity)
                        .padding(CaelynSpacing.md)
                        .background(CaelynColor.alertRose.opacity(0.1), in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, CaelynSpacing.md)

                Spacer()
            }
            .padding(.top, CaelynSpacing.md)
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("When did it start?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingPeriodStartSheet = false }
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        movePeriodStart(to: periodStartDraft)
                        showingPeriodStartSheet = false
                    }
                    .font(CaelynFont.body.weight(.semibold))
                    .foregroundStyle(CaelynColor.primaryPlum)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func movePeriodStart(to newDate: Date) {
        let cal = Calendar.current
        let newDay = cal.startOfDay(for: newDate)
        // Move the flow log to the correct date
        if let old = entries.first(where: { cal.isDate($0.date, inSameDayAs: today) }), old.flow != nil {
            old.flow = nil
            old.updatedAt = .now
        }
        if let existing = entries.first(where: { cal.isDate($0.date, inSameDayAs: newDay) }) {
            if existing.flow == nil { existing.flow = .medium }
            existing.updatedAt = .now
        } else {
            let entry = CycleEntry(date: newDay, flow: .medium)
            modelContext.insert(entry)
        }
        profile?.lastPeriodStart = newDay
        modelContext.saveOrLog()
        Haptics.success()
    }

    private func removePeriodLog() {
        let cal = Calendar.current
        if let entry = entries.first(where: { cal.isDate($0.date, inSameDayAs: today) }) {
            entry.flow = nil
            entry.updatedAt = .now
        }
        if Calendar.current.isDateInToday(profile?.lastPeriodStart ?? .distantPast) {
            profile?.lastPeriodStart = nil
        }
        modelContext.saveOrLog()
        Haptics.selection()
    }

    /// Quick action: mark today as a Medium-flow period day. If today starts
    /// a new cycle (yesterday had no flow), update the profile's
    /// lastPeriodStart so predictions self-correct immediately.
    private func logPeriodToday() {
        let target: CycleEntry
        if let existing = todayEntry {
            // Toggle: if flow is already logged, remove it (undo accidental tap)
            if existing.flow != nil {
                existing.flow = nil
                existing.updatedAt = .now
                modelContext.saveOrLog()
                Haptics.selection()
                return
            }
            existing.flow = .medium
            existing.updatedAt = .now
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
            existing.mood = existing.mood == mood ? nil : mood
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

    // MARK: - Irregular Mode Banner

    @ViewBuilder
    private var irregularModeBanner: some View {
        // Show when auto-detection fires but the user hasn't dismissed or already enabled the mode.
        if case .irregular(let reason) = irregularStatus,
           !(profile?.irregularModeDismissed ?? false),
           !(profile?.irregularModeEnabled ?? false) {
            CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.lavender.opacity(0.55)) {
                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CaelynColor.primaryPlum)
                        Text("Your cycles look a bit irregular")
                            .font(CaelynFont.callout.weight(.semibold))
                            .foregroundStyle(CaelynColor.deepPlumText)
                    }
                    Text(reason.note)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: CaelynSpacing.sm) {
                        Button {
                            profile?.irregularModeEnabled = true
                            profile?.irregularModeDismissed = true
                        } label: {
                            Text("Enable irregular mode")
                                .font(CaelynFont.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(CaelynColor.primaryPlum, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            profile?.irregularModeDismissed = true
                        } label: {
                            Text("Dismiss")
                                .font(CaelynFont.caption)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }
        } else if profile?.irregularModeEnabled == true {
            // Small persistent badge when mode is explicitly on
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 11, weight: .medium))
                Text("Irregular mode on")
                    .font(CaelynFont.caption.weight(.medium))
            }
            .foregroundStyle(CaelynColor.primaryPlum.opacity(0.75))
            .padding(.horizontal, CaelynSpacing.sm)
            .padding(.vertical, 5)
            .background(CaelynColor.lavender.opacity(0.55), in: Capsule())
        }
    }
}

#Preview("Home — populated") {
    HomeView()
        .modelContainer(Persistence.preview)
}
