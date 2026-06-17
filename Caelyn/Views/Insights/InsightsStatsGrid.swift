import SwiftUI

struct InsightsStatsGrid: View {
    let avgCycleLength: Int
    let avgPeriodLength: Int
    let cycleVariation: Int
    let daysLoggedRecent: Int

    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var columns: [GridItem] {
        let count = hSizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible()), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: CaelynSpacing.sm) {
            StatCard(value: "\(avgCycleLength)", label: "Avg cycle", unit: "days",
                     hint: "Day 1 of flow to Day 1 of next flow")
            StatCard(value: "\(avgPeriodLength)", label: "Avg period", unit: "days",
                     hint: "How long your flow typically lasts")
            StatCard(
                value: "±\(cycleVariation)",
                label: "Variation",
                unit: cycleVariation == 1 ? "day" : "days",
                hint: cycleVariation <= 4 ? "Your cycle is quite regular" : "Cycles vary — predictions are wider",
                accent: cycleVariation > 4 ? CaelynColor.alertRose : CaelynColor.successSage
            )
            StatCard(value: "\(daysLoggedRecent)", label: "Logged", unit: "in 30 days",
                     hint: "More logs = more accurate predictions")
        }
    }
}
