import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @State private var isLoaded = false

    private var hasOnboarded: Bool {
        profiles.first?.hasOnboarded ?? false
    }

    var body: some View {
        Group {
            if isLoaded {
                if hasOnboarded {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    OnboardingFlow()
                        .transition(.opacity)
                }
            } else {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasOnboarded)
        .task {
            // Brief delay lets SwiftData hydrate from the store before we make
            // routing decisions. Without this, a brief [] from @Query would
            // incorrectly flash the onboarding screen on returning users.
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation { isLoaded = true }
        }
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
    /// Empty in-memory container used only by the "First launch" Xcode preview
    /// to verify the onboarding flow renders. Mirrors `Persistence.preview`'s
    /// do/catch + fatalError pattern so we don't have a stray `try!` in the
    /// codebase. This code path never runs in shipped builds.
    @MainActor
    static var firstLaunchPreview: ModelContainer {
        let schema = Schema([CycleEntry.self, UserProfile.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create firstLaunchPreview ModelContainer: \(error)")
        }
    }
}
