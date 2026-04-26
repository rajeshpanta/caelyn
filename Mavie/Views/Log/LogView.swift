import SwiftUI

struct LogView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                    todayCard
                    InsightCard(
                        title: "Coming next",
                        message: "Phase 9 brings flow, pain, symptoms, mood, and notes — all in under 10 seconds.",
                        icon: "square.and.pencil"
                    )
                }
                .padding(MavieSpacing.lg)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Log")
        }
    }

    private var todayCard: some View {
        MavieCard {
            VStack(alignment: .leading, spacing: MavieSpacing.xs) {
                Text(today.uppercased())
                    .font(MavieFont.caption.weight(.semibold))
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                    .tracking(0.5)
                Text("Today's check-in")
                    .font(MavieFont.title2)
                    .foregroundStyle(MavieColor.deepPlumText)
                Text("Log your flow, mood, and how you're feeling — fast.")
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: .now)
    }
}

#Preview {
    LogView()
}
