import SwiftUI

struct InsightsStatsGrid: View {
    let avgCycleLength: Int
    let avgPeriodLength: Int
    let cycleVariation: Int
    let daysLoggedRecent: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CaelynSpacing.sm) {
            StatCard(value: "\(avgCycleLength)", label: "Avg cycle", unit: "days")
            StatCard(value: "\(avgPeriodLength)", label: "Avg period", unit: "days")
            StatCard(
                value: "±\(cycleVariation)",
                label: "Variation",
                unit: cycleVariation == 1 ? "day" : "days",
                accent: cycleVariation > 4 ? CaelynColor.alertRose : CaelynColor.successSage
            )
            StatCard(value: "\(daysLoggedRecent)", label: "Logged", unit: "in 30 days")
        }
    }
}
