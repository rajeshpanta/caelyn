import SwiftUI
import SwiftData

struct LogView: View {
    @Query private var profiles: [UserProfile]

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: .now)
    }

    private var cycleDay: Int {
        guard let profile = profiles.first, let lastPeriod = profile.lastPeriodStart else { return 1 }
        return PredictionEngine.currentCycleDay(
            lastPeriodStart: lastPeriod,
            cycleLength: profile.averageCycleLength
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                    header
                    DailyLogForm(date: .now)
                }
                .padding(.horizontal, MavieSpacing.lg)
                .padding(.top, MavieSpacing.md)
                .padding(.bottom, MavieSpacing.xl)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Log")
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todayLabel)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(MavieColor.deepPlumText)
            HStack(spacing: 6) {
                Text("Today's check-in")
                Text("·")
                Text("Cycle day \(cycleDay)")
            }
            .font(MavieFont.subheadline)
            .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
        }
    }
}

#Preview {
    LogView()
        .modelContainer(Persistence.preview)
}
