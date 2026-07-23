import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var showingLogSheet = false
    @State private var showingPeriodStartSheet = false
    @State private var periodStartDraft: Date = .now
    @State private var purchase = PurchaseService.shared

    @AppStorage("caelyn.softPaywallShown") private var softPaywallShown = false
    @AppStorage("caelyn.firstPredictionCelebrated") private var firstPredictionCelebrated = false
    @AppStorage("caelyn.periodRecapDismissedFor") private var recapDismissedFor: Double = 0
    @AppStorage("caelyn.firstFlowCelebrated") private var firstFlowCelebrated = false
    @AppStorage("caelyn.firstWeekCelebrated") private var firstWeekCelebrated = false
    @State private var showingWeekShare = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSoftPaywall = false

    /// The period anchor as it was just before "Log Period today" moved it to today,
    /// so an immediate undo can restore it rather than wiping the baseline (review HIGH).
    @State private var anchorBeforeTodayLog: Date?

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

    /// Per-user luteal length learned from confirmed ovulation signals; 14-day
    /// default until enough data (int-1).
    private var lutealLength: Int {
        PredictionEngine.learnedLutealLength(entries: entries, cycles: cycles) ?? 14
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
        return PredictionEngine.phase(forCycleDay: cycleDay, periodLength: periodLength, cycleLength: cycleLength, lutealLength: lutealLength)
    }

    /// Everything the personalized hint + guide sheet need (nil until 1 cycle
    /// exists, so day-1 users keep the static hint and generic guide).
    private var guidePersonal: PhaseGuidePersonal? {
        guard phase != .unknown, !cycles.isEmpty else { return nil }
        let gentle = profile?.gentleModeEnabled ?? false
        let insights = PatternEngine.insights(from: entries, cycles: cycles, profile: profile)
        let patternLine = insights.first { $0.relatedPhase == phase }?.body
        let teaching = CycleSummaryService.TeachingFacts(
            phase: phase,
            cycleDay: cycleDay,
            cycleCount: cycles.count,
            topPatternLine: patternLine,
            gentle: gentle
        )
        return PhaseGuidePersonal(
            teaching: teaching,
            avgCycle: cycleLength,
            periodLength: periodLength,
            variation: PredictionEngine.cycleLengthVariation(of: cycles),
            avgPain: CycleAnalytics.averagePeriodPain(entries: entries, cycles: cycles).map { Int($0.rounded()) },
            learnedLuteal: PredictionEngine.learnedLutealLength(entries: entries, cycles: cycles),
            pmsDaysBefore: PredictionEngine.adaptivePmsDaysBefore(entries: entries, cycles: cycles)
        )
    }

    /// Distinct calendar days she has ever logged — powers the one-week milestone.
    private var loggedDayCount: Int {
        Set(entries.filter(\.hasContent).map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    /// Days since onboarding — so imported history can't trigger a "one week"
    /// milestone on day 1 (the account itself must be a week old).
    private var daysSinceOnboarding: Int {
        guard let created = profile?.createdAt else { return 0 }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: created), to: today).day ?? 0
    }

    /// Only true when TODAY's entry has flow — so the "first period logged"
    /// celebration fires on the real act of logging, never retroactively for
    /// imported history.
    private var loggedFlowToday: Bool { todayEntry?.flow != nil }

    /// Note-to-self reminders that are due now and not yet cleared — they wait as
    /// a gentle card on Home (belt-and-suspenders with the notification).
    private var dueNoteReminders: [CycleEntry] {
        let now = Date()
        return entries
            .filter { e in
                !e.noteReminderDone
                    && (e.note?.isEmpty == false)
                    && (e.noteReminderAt.map { $0 <= now } ?? false)
            }
            .sorted { ($0.noteReminderAt ?? .distantPast) > ($1.noteReminderAt ?? .distantPast) }
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
        let ovulation = PredictionEngine.ovulationEstimate(nextPeriodStart: nextStart, lutealLength: lutealLength)
        return PredictionEngine.daysUntil(ovulation, from: today)
    }

    private var fertileWindow: ClosedRange<Date>? {
        guard let nextStart else { return nil }
        return PredictionEngine.fertileWindow(nextPeriodStart: nextStart, lutealLength: lutealLength)
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
            nextPeriodStart: nextStart,
            lutealLength: lutealLength
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
                    confidence: confidence,
                    personal: guidePersonal
                )

                // One-time celebration the first time a real prediction exists —
                // the "it works" moment (stand-out plan S4). Dismiss persists.
                if !firstPredictionCelebrated, lastPeriodStart != nil {
                    firstPredictionCard
                }

                // Celebrate the FIRST period log — the earliest, most fragile
                // logs deserve a win, not just the end-of-cycle recap (delight S6).
                if !firstFlowCelebrated, loggedFlowToday {
                    firstFlowCard
                }

                // A gentle milestone at exactly the week-2 novelty cliff — but only
                // for genuine week-long use, never day-1 for imported history.
                if !firstWeekCelebrated, loggedDayCount >= 7, daysSinceOnboarding >= 6 {
                    firstWeekCard
                }

                // Due note-to-self reminders wait here as a gentle card.
                ForEach(dueNoteReminders.prefix(2), id: \.date) { entry in
                    noteReminderCard(entry)
                }

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

                // "This cycle" recap, shown for a few days after a period ends —
                // the #1 churn cliff is right after period week (stand-out plan S6).
                if let recap = periodRecap, recapDismissedFor != recap.start.timeIntervalSince1970 {
                    periodRecapCard(recap)
                }

                periodStartEditRow

                irregularModeBanner

                if purchase.isPro && profile?.ttcEnabled == true {
                    TTCDashboardCard(result: ttcResult, nextPeriodStart: nextStart)
                }

                if purchase.isPro && profile?.pregnancyEnabled == true, let due = profile?.pregnancyDueDate {
                    PregnancyModeCard(dueDate: due)
                }

                if purchase.isPro && profile?.postpartumEnabled == true, let birth = profile?.postpartumBirthDate {
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
                        variation: PredictionEngine.cycleLengthVariation(of: cycles),
                        isLate: isPeriodLate
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
            // A gentle "wake up for you" fade-in the first time Home appears.
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .background(backgroundLayer.ignoresSafeArea())
        .onAppear {
            maybeShowSoftPaywall()
            if reduceMotion { appeared = true }
            else if !appeared { withAnimation(.easeOut(duration: 0.45)) { appeared = true } }
        }
        .sheet(isPresented: $showSoftPaywall) { PaywallView() }
    }

    /// Show the Pro paywall ONCE, the first time the user actually has a real
    /// prediction to look at — a dismissible soft prompt at the value moment, never
    /// on a blank first launch and never for existing Pro users (mon-4).
    private func maybeShowSoftPaywall() {
        guard !softPaywallShown, !purchase.isPro, phase != .unknown else { return }
        softPaywallShown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if !purchase.isPro { showSoftPaywall = true }
        }
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

    // MARK: - Period-end recap (S6)

    private struct PeriodRecap {
        let start: Date
        let length: Int
        let cycleLength: Int?
        let topSymptom: Symptom?
        let avgPain: Int?
    }

    /// The just-finished period, if it ended 1–3 days ago (and ran ≥ 2 days, so a
    /// one-off spotting day doesn't trigger it). Nil otherwise.
    private var periodRecap: PeriodRecap? {
        let cal = Calendar.current
        guard let start = PredictionEngine.mostRecentPeriodStart(from: entries, today: today) else { return nil }
        let flowDays = Set(entries.filter { $0.flow != nil }.map { cal.startOfDay(for: $0.date) })

        var length = 0
        var cursor = start
        while flowDays.contains(cursor) {
            length += 1
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        guard length >= 2,
              let lastFlowDay = cal.date(byAdding: .day, value: length - 1, to: start)
        else { return nil }

        let daysSinceEnd = cal.dateComponents([.day], from: lastFlowDay, to: today).day ?? 99
        guard (1...3).contains(daysSinceEnd) else { return nil }

        // The cycle that ENDED at this period's start, if we have it.
        let completedLength: Int? = cycles.last.flatMap { last in
            cal.date(byAdding: .day, value: last.length, to: last.start)
                .flatMap { cal.isDate($0, inSameDayAs: start) ? last.length : nil }
        }

        let periodEntries = entries.filter {
            let d = cal.startOfDay(for: $0.date)
            return d >= start && d <= lastFlowDay
        }
        let topSymptom = periodEntries
            .flatMap(\.symptoms)
            .reduce(into: [Symptom: Int]()) { $0[$1, default: 0] += 1 }
            .max { $0.value < $1.value }?.key
        let pains = periodEntries.compactMap(\.pain)
        let avgPain = pains.isEmpty ? nil : Int((Double(pains.reduce(0, +)) / Double(pains.count)).rounded())

        return PeriodRecap(start: start, length: length, cycleLength: completedLength, topSymptom: topSymptom, avgPain: avgPain)
    }

    private func periodRecapCard(_ recap: PeriodRecap) -> some View {
        var lines: [String] = ["Your period ran \(recap.length) day\(recap.length == 1 ? "" : "s")."]
        if let cycleLength = recap.cycleLength { lines.append("The full cycle was \(cycleLength) days.") }
        if let symptom = recap.topSymptom { lines.append("Most-logged symptom: \(symptom.displayName.lowercased()).") }
        if let pain = recap.avgPain, pain > 0 { lines.append("Average pain \(pain)/10.") }

        return CaelynCard(padding: CaelynSpacing.md) {
            HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(CaelynColor.successSage)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text("That cycle, in review")
                        .font(CaelynFont.callout.weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(lines.joined(separator: " "))
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation { recapDismissedFor = recap.start.timeIntervalSince1970 }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss recap")
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - First-prediction celebration (one-time)

    private var firstPredictionCard: some View {
        CaelynCard(padding: CaelynSpacing.md, background: phase.tintBackground.opacity(0.5)) {
            HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your predictions are live 🎉")
                        .font(CaelynFont.callout.weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(nextStart.map { "Next period expected around \($0.formatted(.dateTime.month(.wide).day())). Every log from here makes Caelyn smarter about your body." }
                         ?? "Every log from here makes Caelyn smarter about your body.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation { firstPredictionCelebrated = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
    }

    // MARK: - One-time milestone cards (dismiss-and-forget, no nag)

    private func celebrationCard(icon: String, title: String, message: String, onShare: (() -> Void)? = nil, onDismiss: @escaping () -> Void) -> some View {
        // Phase-tinted: the celebration wears the color of where she is in her
        // cycle (rose/sage/lavender/sand) — the ring's language, everywhere.
        CaelynCard(padding: CaelynSpacing.md, background: phase.tintBackground.opacity(0.5)) {
            HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .frame(width: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(CaelynFont.callout.weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(message)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let onShare {
                    Button { onShare() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CaelynColor.primaryPlum)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share this moment")
                }
                Button { withAnimation { onDismiss() } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
    }

    private func noteReminderCard(_ entry: CycleEntry) -> some View {
        CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.blush.opacity(0.5)) {
            HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("A note to yourself")
                        .font(CaelynFont.caption.weight(.semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .tracking(0.3)
                    Text(entry.note ?? "")
                        .font(CaelynFont.callout)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button { markNoteReminderDone(entry) } label: {
                    Text("Done")
                        .font(CaelynFont.caption.weight(.semibold))
                        .foregroundStyle(CaelynColor.onPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(CaelynColor.primaryPlum, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark note reminder done")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func markNoteReminderDone(_ entry: CycleEntry) {
        withAnimation { entry.noteReminderDone = true }
        modelContext.saveOrLog()
        Task { await NotificationService.syncFromLiveStore() }
    }

    private var firstFlowCard: some View {
        celebrationCard(
            icon: "drop.fill",
            title: "Period logged",
            message: "Caelyn just learned something about your body. Keep logging and your predictions get sharper every cycle."
        ) { firstFlowCelebrated = true }
    }

    private var firstWeekCard: some View {
        celebrationCard(
            icon: "heart.circle.fill",
            title: "One week of listening to yourself 🌙",
            message: "Seven days of showing up for you. This is how Caelyn learns your rhythm — gently, and only for you.",
            onShare: { showingWeekShare = true }
        ) { firstWeekCelebrated = true }
        .sheet(isPresented: $showingWeekShare) {
            ShareCardSheet(moment: .oneWeek)
                .presentationDetents([.large])
        }
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
        guard let lastPeriodStart else { return false }
        // Late if today is past the *un-rolled* expected start AND nothing has
        // been logged in the active period window. `nextStart` is rolled forward
        // to always be >= today, so it could never detect lateness (stz-009).
        let expected = PredictionEngine.expectedPeriodStart(
            lastPeriodStart: lastPeriodStart,
            cycleLength: cycleLength
        )
        return today > expected && activePeriodWindow == nil
    }

    private var daysLate: Int {
        guard let lastPeriodStart else { return 0 }
        return PredictionEngine.daysLate(
            lastPeriodStart: lastPeriodStart,
            today: today,
            cycleLength: cycleLength
        )
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
        // daysLate is always >= 1 here (periodStatePrompt gates on it), so there
        // is no `case 0` — it would be dead (stz-009).
        switch daysLate {
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
        // Only create a flow entry for the stated start date if one doesn't exist.
        // Existing logs on any other dates are intentionally left untouched —
        // historical logs are the source of truth for cycle tracking and exports.
        // Users can clear any day's log themselves via the Log tab.
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
        var entryToSync: CycleEntry?
        if let entry = entries.first(where: { cal.isDate($0.date, inSameDayAs: today) }) {
            entry.flow = nil
            entry.updatedAt = .now
            entryToSync = entry
        }
        if cal.isDateInToday(profile?.lastPeriodStart ?? .distantPast) {
            // Recompute from remaining flow rather than blindly nil-ing (review HIGH).
            profile?.lastPeriodStart = PredictionEngine.mostRecentPeriodStart(from: entries, today: today)
        }
        modelContext.saveOrLog()
        Haptics.selection()
        if let captured = entryToSync {
            let snapshot = entries
            Task { await HealthKitSync.syncIfConnected(captured, in: snapshot, modelContext: modelContext) }
        }
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
                // If today was the recorded period start, RESTORE the prior anchor
                // rather than nil-ing it — nil-ing wipes an established user's whole
                // baseline on an accidental-tap undo (review HIGH). Prefer the value
                // captured before this tap; else the most recent prior flow streak.
                if Calendar.current.isDateInToday(profile?.lastPeriodStart ?? .distantPast) {
                    profile?.lastPeriodStart = anchorBeforeTodayLog
                        ?? PredictionEngine.mostRecentPeriodStart(from: entries, today: today)
                }
                anchorBeforeTodayLog = nil
                modelContext.saveOrLog()
                let snapshot = entries
                let captured = existing
                Task { await HealthKitSync.syncIfConnected(captured, in: snapshot, modelContext: modelContext) }
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
                anchorBeforeTodayLog = profile?.lastPeriodStart   // remember for an undo
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
