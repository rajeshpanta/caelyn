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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                    if cycles.count < 3 {
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

#Preview {
    InsightsView()
        .modelContainer(Persistence.preview)
}
