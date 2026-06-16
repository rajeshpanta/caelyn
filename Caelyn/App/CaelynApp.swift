import SwiftUI
import SwiftData
import WidgetKit
import WatchConnectivity

@main
struct CaelynApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppLockGate {
                ThemedContentView()
                    .appPreviewMask()
                    .syncWidgetData()
            }
            .task {
                await PurchaseService.shared.loadProducts()
                WatchBridgeService.shared.activate()
            }
        }
        .modelContainer(Persistence.live)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
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
