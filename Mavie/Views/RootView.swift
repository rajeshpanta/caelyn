import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]

    private var hasOnboarded: Bool {
        profiles.first?.hasOnboarded ?? false
    }

    var body: some View {
        Group {
            if hasOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasOnboarded)
    }
}

#Preview("Onboarded") {
    RootView()
        .modelContainer(Persistence.preview)
}

#Preview("First launch") {
    RootView()
        .modelContainer(.firstLaunchPreview)
}

extension ModelContainer {
    @MainActor
    static var firstLaunchPreview: ModelContainer {
        let schema = Schema([CycleEntry.self, UserProfile.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
