import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Query private var profiles: [UserProfile]

    @State private var purchase = PurchaseService.shared
    @State private var showingPaywall = false

    private var profile: UserProfile? { profiles.first }

    private var cycles: [Cycle] {
        PredictionEngine.cycles(from: entries)
    }

    private var patternInsights: [PatternInsight] {
        PatternEngine.insights(from: entries, cycles: cycles, profile: profile)
    }

    private var avgCycleLength: Int {
        PredictionEngine.averageCycleLength(of: cycles, fallback: profile?.averageCycleLength ?? 28)
    }

    private var avgPeriodLength: Int {
        PredictionEngine.averagePeriodLength(of: cycles, fallback: profile?.averagePeriodLength ?? 5)
    }

    private var cycleVariation: Int {
        PredictionEngine.cycleLengthVariation(of: cycles)
    }

    private var confidence: Confidence {
        PredictionEngine.confidence(cycleCount: cycles.count)
    }

    // Current-state facts for the on-device summary (int-4) + temperature (int-3).
    private var lastStart: Date? { profile?.lastPeriodStart }
    private var currentCycleDay: Int {
        guard let l = lastStart else { return 1 }
        return PredictionEngine.currentCycleDay(lastPeriodStart: l, cycleLength: avgCycleLength)
    }
    private var nextStart: Date? {
        guard let l = lastStart else { return nil }
        return PredictionEngine.nextPeriodStart(lastPeriodStart: l, cycleLength: avgCycleLength)
    }
    private var currentPhase: CyclePhase {
        guard lastStart != nil else { return .unknown }
        return PredictionEngine.phase(forCycleDay: currentCycleDay, periodLength: avgPeriodLength, cycleLength: avgCycleLength)
    }
    private var daysUntilPeriod: Int {
        guard let n = nextStart else { return 0 }
        return PredictionEngine.daysUntil(n, from: .now)
    }
    private var bbtSeries: [(date: Date, temp: Double)] {
        entries.compactMap { e in e.basalTemperature.map { (date: e.date, temp: $0) } }
    }
    private var summaryFacts: CycleSummaryService.Facts {
        CycleSummaryService.Facts(
            avgCycle: avgCycleLength,
            avgPeriod: avgPeriodLength,
            variation: cycleVariation,
            phaseName: currentPhase.displayName,
            cycleDay: currentCycleDay,
            daysUntilPeriod: daysUntilPeriod,
            topInsight: patternInsights.first?.title
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                    if cycles.count < 2 {
                        InsightsEmptyState(cyclesLogged: cycles.count, confidence: confidence)
                    } else {
                        loadedContent
                    }
                }
                .padding(.horizontal, CaelynSpacing.lg)
                .padding(.top, CaelynSpacing.md)
                .padding(.bottom, CaelynSpacing.xl)
                .caelynContentWidth()
                .frame(maxWidth: .infinity)
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Insights")
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .onChange(of: showingPaywall) { _, isShowing in
            if !isShowing {
                // Force the purchase state to refresh after paywall dismissal
                purchase = PurchaseService.shared
            }
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        InsightsStatsGrid(
            avgCycleLength: avgCycleLength,
            avgPeriodLength: avgPeriodLength,
            cycleVariation: cycleVariation,
            daysLoggedRecent: CycleAnalytics.daysLogged(in: entries)
        )

        PatternsSection(
            cycles: cycles,
            mostCommonEarlyPeriodSymptom: CycleAnalytics.mostCommonEarlyPeriodSymptom(entries: entries, cycles: cycles),
            averagePeriodPain: CycleAnalytics.averagePeriodPain(entries: entries, cycles: cycles),
            cycleVariation: cycleVariation
        )

        if !patternInsights.isEmpty {
            PatternInsightsSection(
                insights: patternInsights,
                isPro: purchase.isPro,
                onUpgrade: { showingPaywall = true }
            )
        }

        YearViewSection(
            entries: entries,
            profile: profile,
            isPro: purchase.isPro,
            onUpgrade: { showingPaywall = true }
        )

        CycleHistorySection(cycles: cycles, entries: entries)

        if purchase.isPro {
            CycleSummaryCard(facts: summaryFacts)
            TemperatureShiftCard(
                windowStart: Calendar.current.date(byAdding: .day, value: -40, to: .now) ?? .now,
                bbtSeries: bbtSeries
            )
            CycleLengthChart(series: CycleAnalytics.cycleLengthSeries(from: cycles))
            PeriodLengthChart(series: CycleAnalytics.periodLengthSeries(from: cycles))
            SymptomFrequencyChart(counts: CycleAnalytics.symptomFrequency(in: entries))
            MoodPatternChart(counts: CycleAnalytics.moodFrequency(in: entries))
            PainTrendChart(series: CycleAnalytics.painSeries(in: entries))
            BBTChart(series: CycleAnalytics.bbtSeries(in: entries))
        } else {
            ProUpsellCard(
                title: "Your body has more to say",
                subtitle: "Pro reveals the patterns free can't show — what triggers your symptoms, when your energy peaks, and why your cycle varies.",
                icon: "chart.line.uptrend.xyaxis",
                highlights: [
                    "Cycle & period length trends",
                    "Symptom frequency over time",
                    "Mood & pain charts",
                    "Basal body temperature graph",
                    "PDF report for your doctor",
                    "TTC fertility scoring",
                    "Apple Watch + Home Screen widgets"
                ],
                featureIcons: ["chart.bar.fill", "brain", "heart.text.square.fill", "doc.richtext.fill", "applewatch"]
            ) {
                showingPaywall = true
            }
        }
    }
}

// MARK: - Private Intelligence cards (Pro)

/// On-device natural-language cycle summary (Foundation Models when available,
/// deterministic template otherwise) — int-4.
private struct CycleSummaryCard: View {
    let facts: CycleSummaryService.Facts
    @State private var text: String?

    var body: some View {
        CaelynCard {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                Label("Your cycle in words", systemImage: "sparkles")
                    .font(CaelynFont.headline)
                    .foregroundStyle(CaelynColor.primaryPlum)
                Text(text ?? CycleSummaryService.fallback(facts: facts))
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Generated privately on your device.")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
            }
        }
        .task { text = await CycleSummaryService.summary(for: facts) }
    }
}

/// Retrospective ovulation confirmation from Apple Watch wrist temperature (or
/// logged BBT). Renders nothing unless a clear biphasic shift is found — int-3.
private struct TemperatureShiftCard: View {
    let windowStart: Date
    let bbtSeries: [(date: Date, temp: Double)]
    @State private var result: WristTempOvulationEngine.Result?

    var body: some View {
        Group {
            if let r = result, r.detected, let ovulation = r.estimatedOvulation {
                CaelynCard {
                    HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                        Image(systemName: "thermometer.sun.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(CaelynColor.successSage)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Temperature shift detected")
                                .font(CaelynFont.callout.weight(.semibold))
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text("Your temperature rose around \(ovulation.formatted(.dateTime.month(.abbreviated).day())), which usually follows ovulation. Observational only — not a medical or contraceptive method.")
                                .font(CaelynFont.subheadline)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .task {
            let wrist = await HealthKitService.fetchWristTemperatures(from: windowStart, to: .now)
            let series = wrist.isEmpty ? bbtSeries : wrist
            result = WristTempOvulationEngine.detectShift(in: series)
        }
    }
}

#Preview {
    InsightsView()
        .modelContainer(Persistence.preview)
}
