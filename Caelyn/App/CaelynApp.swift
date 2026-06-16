import SwiftUI
import SwiftData
import WidgetKit
import WatchConnectivity

@main
struct CaelynApp: App {
    /// Registers UNUserNotificationCenterDelegate at app launch so taps are
    /// captured and the smart-tap router can route to the right card. See
    /// AppDelegate.swift.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppLockGate {
                ContentView()
                    .appPreviewMask()
                    .syncWidgetData()
            }
            .applyCaelynTheme()
            .task {
                // Run on first appearance so PurchaseService.shared is created
                // and its Transaction.updates listener starts as early as
                // possible. Also primes Product.products(for:) and reads
                // Transaction.currentEntitlements before the user can reach
                // the paywall / Insights / Export.
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

private struct ApplyCaelynThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

private extension View {
    func applyCaelynTheme() -> some View {
        modifier(ApplyCaelynThemeModifier())
    }
}
