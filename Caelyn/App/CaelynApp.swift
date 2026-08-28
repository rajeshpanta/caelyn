import SwiftUI
import SwiftData
import WidgetKit
import WatchConnectivity

@main
struct CaelynApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private static let isScreenshotMode = CommandLine.arguments.contains("--screenshot-mode")
                                        || CommandLine.arguments.contains("--screenshot-paywall")
    private static let isPaywallMode    = CommandLine.arguments.contains("--screenshot-paywall")
    private static let isOnboardingUITest = CommandLine.arguments.contains("--ui-test-onboarding")

    /// A file handed to Caelyn from Files, Mail or another app's share sheet.
    /// Held here rather than deeper in the view tree so it survives the app lock
    /// and is presented once the app is actually usable.
    @State private var incomingFile: IncomingImportFile?

    /// Keeps the one-entry-per-day invariant true while CloudKit is delivering
    /// records mid-session. Built only for the live store: the screenshot and
    /// UI-test containers are in-memory and have nothing to sync.
    @State private var syncCoordinator: CloudSyncCoordinator? = {
        guard !isScreenshotMode, !isOnboardingUITest else { return nil }
        return CloudSyncCoordinator(container: Persistence.live)
    }()

    var body: some Scene {
        WindowGroup {
            AppLockGate {
                ThemedContentView()
                    .appPreviewMask()
                    .syncWidgetData()
                    .sheet(item: $incomingFile) { file in
                        BringHistoryView(incomingFile: file)
                    }
            }
            .onOpenURL { url in
                // Read the bytes now, while the security scope is open, and hold
                // those instead of the URL — by the time the sheet presents, the
                // original location may no longer be reachable.
                if let file = IncomingImportFile(openedAt: url) { incomingFile = file }
            }
            .task {
                if Self.isOnboardingUITest {
                    return
                } else if Self.isScreenshotMode {
                    if !Self.isPaywallMode {
                        PurchaseService.shared.overridePro(true)
                    }
                } else {
                    await PurchaseService.shared.loadProducts()
                    WatchBridgeService.shared.activate()
                    syncCoordinator?.start()
                    await reconcileAppleCredential()
                    // If she deleted her iCloud copy, make sure it stayed deleted.
                    // Covers an interrupted deletion and a mirroring delegate that
                    // recreated the zone before it was detached.
                    await CloudDataDeletion.resolveOutstandingDeletion()
                    // And honour a deletion made on a *different* device, which
                    // this one would otherwise undo by recreating the zone.
                    await CloudDataDeletion.honourRemoteDeletionIfNeeded()
                }
            }
        }
        .modelContainer(
            Self.isOnboardingUITest
                ? ModelContainer.firstLaunchPreview
                : (Self.isScreenshotMode ? Persistence.screenshot : Persistence.live)
        )
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !Self.isScreenshotMode && !Self.isOnboardingUITest {
                Task { await NotificationService.syncFromLiveStore() }
                Task { await PurchaseService.shared.loadProducts() }
                // Pick up anything other apps wrote to Apple Health while Caelyn
                // was closed. No-op unless she has connected and left a read
                // toggle on.
                Task { await HealthSyncService.syncOnForeground() }
                // Apple can revoke the credential while Caelyn is backgrounded.
                // Checking on foreground keeps the signed-in state honest — and an
                // unreachable Apple deliberately changes nothing.
                Task { await reconcileAppleCredential() }
            }
        }
    }

    /// Ask Apple whether the stored credential still stands.
    ///
    /// Only ever ends the local session on an unambiguous revoked/notFound. Cycle
    /// history is never involved: `AccountSession` cannot reach it.
    @MainActor
    private func reconcileAppleCredential() async {
        guard let userID = AccountIdentityStore.appleUserID else { return }
        let state = await AppleSignInService.credentialState(for: userID)
        let context = Persistence.live.mainContext
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
        if AccountSession.reconcile(state, profile: profile) {
            context.saveOrLog()
        }
    }
}

/// Reads the user's theme preference and applies `preferredColorScheme`.
private struct ThemedContentView: View {
    @Query private var profiles: [UserProfile]

    private var colorScheme: ColorScheme? {
        switch profiles.first?.theme ?? .system {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }

    var body: some View {
        ContentView()
            .preferredColorScheme(colorScheme)
    }
}
