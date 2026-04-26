import SwiftUI
import SwiftData

@main
struct MavieApp: App {
    var body: some Scene {
        WindowGroup {
            AppLockGate {
                ContentView()
                    .appPreviewMask()
                    .applyMavieTheme()
            }
        }
        .modelContainer(Persistence.live)
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
