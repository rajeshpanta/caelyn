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

    var body: some Scene {
        WindowGroup {
            AppLockGate {
                ThemedContentView()
                    .appPreviewMask()
                    .syncWidgetData()
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
            }
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
