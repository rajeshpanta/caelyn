import SwiftUI
import SwiftData

struct AppPreviewMask: ViewModifier {
    @Query private var profiles: [UserProfile]
    @Environment(\.scenePhase) private var scenePhase

    private var hidePreview: Bool { profiles.first?.hidePreview ?? false }
    // Mask whenever the app is not active. The app-switcher snapshot is captured
    // at `.inactive`, so masking only on `.background` leaks content into the
    // switcher. No animation — the shield must be fully opaque in the snapshot,
    // not mid-fade (stz-008).
    private var shouldMask: Bool { hidePreview && scenePhase != .active }

    func body(content: Content) -> some View {
        ZStack {
            content
            if shouldMask {
                CaelynPrivacyShield()
            }
        }
    }
}

extension View {
    func appPreviewMask() -> some View {
        modifier(AppPreviewMask())
    }
}

private struct CaelynPrivacyShield: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CaelynColor.backgroundCream, CaelynColor.lavender.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: CaelynSpacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(CaelynColor.primaryPlum)
                Text("Caelyn")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)
            }
        }
    }
}
