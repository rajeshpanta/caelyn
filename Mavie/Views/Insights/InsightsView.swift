import SwiftUI

struct InsightsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                    placeholderStats
                    InsightCard(
                        title: "Coming next",
                        message: "Phase 11 brings cycle averages, symptom patterns, and trend charts based on your logs.",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                .padding(MavieSpacing.lg)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Insights")
        }
    }

    private var placeholderStats: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            SectionHeader(title: "Your patterns", subtitle: "Based on your last cycles")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MavieSpacing.sm) {
                StatCard(value: "—", label: "Avg cycle", unit: "days")
                StatCard(value: "—", label: "Avg period", unit: "days")
                StatCard(value: "—", label: "Variation", unit: "days")
                StatCard(value: "—", label: "Most common")
            }
        }
    }
}

#Preview {
    InsightsView()
}
