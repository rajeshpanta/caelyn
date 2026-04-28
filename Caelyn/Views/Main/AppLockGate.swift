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
                    canAuthenticate: BiometricService.canAuthenticate,
                    errorMessage: errorMessage,
                    isAuthenticating: attemptingAuth,
                    onUnlock: { Task { await tryUnlock() } }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showLockScreen)
        .task(id: lockEnabled) {
            // If lockEnabled is false, no need to do anything: showLockScreen already
            // returns false when lockEnabled is false, regardless of isUnlocked.
            //
            // We deliberately do NOT set isUnlocked = true on the false branch. That
            // would create a race on cold launch: @Query may briefly return [] before
            // the profile loads, lockEnabled reads as false, isUnlocked flips to true,
            // and when the profile loads with lockEnabled=true the auto-prompt branch
            // is skipped — leaving the user inside the app without authenticating.
            //
            // Authentication is the only path that sets isUnlocked = true.
            if lockEnabled && isUnlocked == false {
                await tryUnlock()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                isUnlocked = false
                errorMessage = nil
            }
            // Foreground resume shows the lock screen; the user taps the
            // Unlock button to authenticate. This avoids a re-prompt loop
            // when the user has already cancelled Face ID once. The initial
            // cold-launch auto-prompt still fires via .task(id: lockEnabled).
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
            try await BiometricService.authenticate(reason: "Unlock Caelyn")
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
    let canAuthenticate: Bool
    let errorMessage: String?
    let isAuthenticating: Bool
    let onUnlock: () -> Void

    private var primaryIcon: String {
        biometricKind == .none ? "lock.fill" : biometricKind.icon
    }

    private var primaryLabel: String {
        biometricKind == .none ? "Passcode" : biometricKind.displayName
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CaelynColor.backgroundCream, CaelynColor.lavender.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: CaelynSpacing.lg) {
                Spacer()
                ZStack {
                    Circle().fill(CaelynColor.lavender).frame(width: 140, height: 140)
                    Image(systemName: primaryIcon)
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }

                VStack(spacing: 6) {
                    Text("Caelyn is locked")
                        .font(.system(.title, design: .rounded).weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(canAuthenticate
                         ? "Unlock with \(primaryLabel) to continue."
                         : "This device has no passcode set up. Add one in iOS Settings to access Caelyn.")
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, CaelynSpacing.lg)

                if let errorMessage {
                    Text(errorMessage)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.alertRose)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CaelynSpacing.lg)
                }

                Spacer()

                CaelynButton(
                    title: isAuthenticating ? "Unlocking…" : "Unlock with \(primaryLabel)",
                    variant: .primary,
                    icon: primaryIcon
                ) {
                    onUnlock()
                }
                .disabled(isAuthenticating || !canAuthenticate)
                .padding(.horizontal, CaelynSpacing.lg)
                .padding(.bottom, CaelynSpacing.lg)
            }
        }
    }
}
