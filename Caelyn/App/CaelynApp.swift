import SwiftUI
import SwiftData
import WidgetKit
import WatchConnectivity

@main
struct CaelynApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private static let isScreenshotMode = CommandLine.arguments.contains("--screenshot-mode")

    var body: some Scene {
        WindowGroup {
            AppLockGate {
                ThemedContentView()
                    .appPreviewMask()
                    .syncWidgetData()
            }
            .task {
                if Self.isScreenshotMode {
                    // Override Pro status for screenshot capture so Pro charts are visible.
                    PurchaseService.shared.overridePro(true)
                } else {
                    await PurchaseService.shared.loadProducts()
                    WatchBridgeService.shared.activate()
                }
            }
        }
        .modelContainer(Self.isScreenshotMode ? Persistence.screenshot : Persistence.live)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !Self.isScreenshotMode {
                Task { await NotificationService.syncFromLiveStore() }
                Task { await PurchaseService.shared.loadProducts() }
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
