import SwiftUI
import SwiftData

@main
struct MavieApp: App {
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
            }
            .applyMavieTheme()
            .task {
                // Run on first appearance so PurchaseService.shared is created
                // and its Transaction.updates listener starts as early as
                // possible. Also primes Product.products(for:) and reads
                // Transaction.currentEntitlements before the user can reach
                // the paywall / Insights / Export.
                await PurchaseService.shared.loadProducts()
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

private struct ApplyMavieThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Locked to light mode until Phase 17 ships dark-variant tokens for the
        // cream/blush/lavender palette. The AppTheme enum and picker remain
        // wired so we can flip this on without re-plumbing.
        content.preferredColorScheme(.light)
    }
}

private extension View {
    func applyMavieTheme() -> some View {
        modifier(ApplyMavieThemeModifier())
    }
}
