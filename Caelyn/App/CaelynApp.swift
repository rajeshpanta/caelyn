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
