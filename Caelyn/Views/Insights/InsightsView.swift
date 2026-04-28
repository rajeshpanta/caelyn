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
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Insights")
        }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
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

        if purchase.isPro {
            CycleLengthChart(series: CycleAnalytics.cycleLengthSeries(from: cycles))
            PeriodLengthChart(series: CycleAnalytics.periodLengthSeries(from: cycles))
            SymptomFrequencyChart(counts: CycleAnalytics.symptomFrequency(in: entries))
            MoodPatternChart(counts: CycleAnalytics.moodFrequency(in: entries))
            PainTrendChart(series: CycleAnalytics.painSeries(in: entries))
        } else {
            ProUpsellCard(
                title: "Unlock advanced charts",
                subtitle: "See how your cycle length, symptoms, mood, and pain change over time.",
                icon: "chart.line.uptrend.xyaxis",
                highlights: [
                    "Cycle & period length trends",
                    "Symptom frequency patterns",
                    "Mood distribution",
                    "Pain levels over time",
                    "PDF cycle reports for your doctor"
                ]
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
