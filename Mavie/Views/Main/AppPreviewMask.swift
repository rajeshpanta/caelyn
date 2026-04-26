import SwiftUI
import SwiftData

struct AppPreviewMask: ViewModifier {
    @Query private var profiles: [UserProfile]
    @Environment(\.scenePhase) private var scenePhase

    private var hidePreview: Bool { profiles.first?.hidePreview ?? false }
    private var shouldMask: Bool { hidePreview && scenePhase != .active }

    func body(content: Content) -> some View {
        ZStack {
            content
            if shouldMask {
                MaviePrivacyShield()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: shouldMask)
    }
}

extension View {
    func appPreviewMask() -> some View {
        modifier(AppPreviewMask())
    }
}

private struct MaviePrivacyShield: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [MavieColor.backgroundCream, MavieColor.lavender.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: MavieSpacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(MavieColor.primaryPlum)
                Text("Mavie")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(MavieColor.deepPlumText)
            }
        }
    }
}
