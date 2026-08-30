import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var isLoaded = false
    @State private var showStoreWarning = UserDefaults.standard.bool(forKey: Persistence.storeFailedKey)

    /// Raise-only latch for the account offer.
    ///
    /// `offerIsDue` may switch this on; only `endAccountOffer()` switches it off.
    /// Binding the sheet straight to the condition dismissed it the instant
    /// `accountLinked` flipped at sign-in, tearing down the name step that runs
    /// next. See `AccountOfferPolicy` for the full account.
    @State private var isOfferingAccount = false

    private var hasOnboarded: Bool {
        profiles.first?.hasOnboarded ?? false
    }

    /// Whether the offer is *due*. Deliberately not the sheet's `isPresented`:
    /// this goes false the moment she signs in, and the sheet must outlive that.
    private var offerIsDue: Bool {
        isLoaded && AccountOfferPolicy.isDue(for: profiles.first)
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
            // Merge any same-day duplicate entries an old-store migration or a
            // sync race could have introduced (Phase 6 removed the `.unique`
            // store constraint; uniqueness-by-day is enforced in code instead).
            CycleStore.dedupeSameDay(in: modelContext)

            // Brief delay lets SwiftData hydrate from the store before we make
            // routing decisions. Without this, a brief [] from @Query would
            // incorrectly flash the onboarding screen on returning users.
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation { isLoaded = true }
        }
        .onChange(of: offerIsDue, initial: true) { _, due in
            // Raise only. Lowering is `endAccountOffer()`'s job alone.
            if due { isOfferingAccount = true }
        }
        .sheet(isPresented: Binding(
            get: { isOfferingAccount },
            set: { if !$0 { endAccountOffer() } }
        )) {
            AccountOfferSheet(profile: profiles.first) { endAccountOffer() }
                .presentationDetents([.large])
        }
        .overlay(alignment: .top) {
            if showStoreWarning { storeWarningBanner }
        }
        .animation(.easeInOut(duration: 0.3), value: showStoreWarning)
    }

    /// Close the offer and record that it was answered, whichever way she went —
    /// declining is an answer, and so is swiping the sheet away.
    private func endAccountOffer() {
        isOfferingAccount = false
        guard let profile = profiles.first, !profile.hasSeenAccountOffer else { return }
        profile.hasSeenAccountOffer = true
        modelContext.saveOrLog()
    }

    /// Shown when the live store couldn't open and Caelyn fell back to a fresh /
    /// in-memory store. Tells the user honestly and points them to Export so they
    /// never discover data loss silently (data-inmemory-safety).
    private var storeWarningBanner: some View {
        HStack(alignment: .top, spacing: CaelynSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Storage problem")
                    .font(CaelynFont.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Caelyn couldn't open your saved data and started fresh. Your previous data was kept aside. Back up regularly from Settings → Export.")
                    .font(CaelynFont.caption)
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                showStoreWarning = false
                UserDefaults.standard.set(false, forKey: Persistence.storeFailedKey)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(CaelynSpacing.md)
        .background(CaelynColor.alertRose, in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
        .padding(.horizontal, CaelynSpacing.md)
        .padding(.top, CaelynSpacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
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
