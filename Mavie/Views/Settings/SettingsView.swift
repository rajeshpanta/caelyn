import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                    DataStatusCard()

                    InsightCard(
                        title: "Coming next",
                        message: "Phase 12 brings Face ID lock, hide-app-preview, exports, theme switcher, and delete-all-data.",
                        icon: "gearshape"
                    )

                    diagnostics
                }
                .padding(MavieSpacing.lg)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Settings")
        }
        .confirmationDialog(
            "Reset onboarding?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { resetOnboarding() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your profile and re-runs onboarding. Logged entries are preserved.")
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            SectionHeader(title: "Diagnostics", subtitle: "Dev-only while we're building")
            MavieCard {
                Button {
                    showingResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward.circle")
                        Text("Reset onboarding")
                            .font(MavieFont.body.weight(.medium))
                    }
                    .foregroundStyle(MavieColor.alertRose)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func resetOnboarding() {
        for profile in profiles {
            modelContext.delete(profile)
        }
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(Persistence.preview)
}
