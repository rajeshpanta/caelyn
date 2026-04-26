import SwiftUI
import SwiftData

struct AppLockGate<Content: View>: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.scenePhase) private var scenePhase

    @State private var isUnlocked = false
    @State private var attemptingAuth = false
    @State private var errorMessage: String?

    let content: () -> Content

    private var lockEnabled: Bool { profiles.first?.lockEnabled ?? false }
    private var hasOnboarded: Bool { profiles.first?.hasOnboarded ?? false }

    var body: some View {
        ZStack {
            content()
                .opacity(showLockScreen ? 0 : 1)
                .allowsHitTesting(!showLockScreen)

            if showLockScreen {
                LockScreen(
                    biometricKind: BiometricService.availableKind(),
                    errorMessage: errorMessage,
                    isAuthenticating: attemptingAuth,
                    onUnlock: { Task { await tryUnlock() } }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showLockScreen)
        .task(id: lockEnabled) {
            if !lockEnabled { isUnlocked = true }
            else if isUnlocked == false { await tryUnlock() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                isUnlocked = false
                errorMessage = nil
            } else if newPhase == .active && lockEnabled && !isUnlocked && !attemptingAuth {
                Task { await tryUnlock() }
            }
        }
    }

    private var showLockScreen: Bool {
        guard hasOnboarded else { return false }
        return lockEnabled && !isUnlocked
    }

    @MainActor
    private func tryUnlock() async {
        guard !attemptingAuth else { return }
        attemptingAuth = true
        errorMessage = nil
        do {
            try await BiometricService.authenticate(reason: "Unlock Mavie")
            isUnlocked = true
        } catch BiometricError.userCancelled {
            // user dismissed — leave them at the lock screen
        } catch {
            errorMessage = error.localizedDescription
        }
        attemptingAuth = false
    }
}

private struct LockScreen: View {
    let biometricKind: BiometricKind
    let errorMessage: String?
    let isAuthenticating: Bool
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [MavieColor.backgroundCream, MavieColor.lavender.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: MavieSpacing.lg) {
                Spacer()
                ZStack {
                    Circle().fill(MavieColor.lavender).frame(width: 140, height: 140)
                    Image(systemName: biometricKind.icon)
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(MavieColor.primaryPlum)
                }

                VStack(spacing: 6) {
                    Text("Mavie is locked")
                        .font(.system(.title, design: .rounded).weight(.semibold))
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text("Unlock with \(biometricKind.displayName) to continue.")
                        .font(MavieFont.body)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, MavieSpacing.lg)

                if let errorMessage {
                    Text(errorMessage)
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.alertRose)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, MavieSpacing.lg)
                }

                Spacer()

                MavieButton(
                    title: isAuthenticating ? "Unlocking…" : "Unlock with \(biometricKind.displayName)",
                    variant: .primary,
                    icon: biometricKind.icon
                ) {
                    onUnlock()
                }
                .disabled(isAuthenticating || biometricKind == .none)
                .padding(.horizontal, MavieSpacing.lg)
                .padding(.bottom, MavieSpacing.lg)
            }
        }
    }
}
