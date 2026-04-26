import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Hi"
        }
    }

    private var cycleDay: Int {
        guard let profile, let lastPeriod = profile.lastPeriodStart else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: lastPeriod, to: .now).day ?? 0
        return max(1, days + 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                    header

                    MavieCard {
                        VStack(spacing: MavieSpacing.md) {
                            CycleRingView(
                                cycleDay: cycleDay,
                                cycleLength: profile?.averageCycleLength ?? 28,
                                periodLength: profile?.averagePeriodLength ?? 5
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }

                    InsightCard(
                        title: "Coming next",
                        message: "Phase 8 brings quick log actions, today's check-in, and pattern insights.",
                        icon: "sparkles"
                    )
                }
                .padding(MavieSpacing.lg)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.xxs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(MavieFont.title2)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text("Cycle day \(cycleDay)")
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                }
                Spacer()
                PrivacyChip()
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(Persistence.preview)
}
