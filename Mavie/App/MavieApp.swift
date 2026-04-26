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
    @Query private var profiles: [UserProfile]

    func body(content: Content) -> some View {
        content.preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch profiles.first?.theme ?? .system {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

private extension View {
    func applyMavieTheme() -> some View {
        modifier(ApplyMavieThemeModifier())
    }
}
