import SwiftUI
import SwiftData

struct AppLockGate<Content: View>: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var isUnlocked = false
    @State private var attemptingAuth = false
    @State private var errorMessage: String?
    @State private var showingPINPad = false
    @State private var pinError: String?

    let content: () -> Content

    private var lockEnabled: Bool { profiles.first?.lockEnabled ?? false }
    private var hasOnboarded: Bool { profiles.first?.hasOnboarded ?? false }

    /// When there's no biometrics but a PIN exists, go straight to the PIN pad.
    private var showPINEntry: Bool {
        showingPINPad || (!BiometricService.canAuthenticate && PINService.isSet)
    }

    var body: some View {
        ZStack {
            content()
                .opacity(showLockScreen ? 0 : 1)
                .allowsHitTesting(!showLockScreen)

            if showLockScreen {
                if showPINEntry {
                    PINPadView(
                        title: "Enter PIN",
                        subtitle: "Unlock Caelyn",
                        length: 4,
                        errorMessage: pinError,
                        onSubmit: verifyPIN,
                        onCancel: BiometricService.canAuthenticate ? { showingPINPad = false; pinError = nil } : nil
                    )
                    .background(CaelynColor.backgroundCream.ignoresSafeArea())
                } else {
                    LockScreen(
                        biometricKind: BiometricService.availableKind(),
                        canAuthenticate: BiometricService.canAuthenticate,
                        pinAvailable: PINService.isSet,
                        errorMessage: errorMessage,
                        isAuthenticating: attemptingAuth,
                        onUnlock: { Task { await tryUnlock() } },
                        onUsePIN: { showingPINPad = true; pinError = nil }
                    )
                }
            }
        }
        .task { await sweepThenRecordActivity() }   // launch: auto-sweep if the window elapsed
        .task(id: lockEnabled) {
            if lockEnabled && !isUnlocked && BiometricService.canAuthenticate {
                await tryUnlock()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Relock when the app actually leaves the foreground.
                isUnlocked = false
                errorMessage = nil
                pinError = nil
                showingPINPad = false
            } else if newPhase == .active {
                Task { await sweepThenRecordActivity() }
                if lockEnabled && !isUnlocked && !attemptingAuth && BiometricService.canAuthenticate {
                    Task { await tryUnlock() }
                }
            }
        }
    }

    private var showLockScreen: Bool {
        guard hasOnboarded, lockEnabled else { return false }
        // Fail OPEN if there's no way to unlock (no biometrics AND no PIN) — a user
        // must never be permanently locked out of their own data.
        guard BiometricService.canAuthenticate || PINService.isSet else { return false }
        // Cover whenever locked OR the app isn't active, so the app-switcher
        // snapshot never exposes content. We only clear isUnlocked on .background.
        return !isUnlocked || scenePhase != .active
    }

    /// Run the opt-in auto-sweep using the PREVIOUS activity timestamp, then stamp
    /// the new one. No-op unless the user enabled auto-wipe (priv-4).
    @MainActor
    private func sweepThenRecordActivity() async {
        await AutoSweepService.checkAndSweep(profile: profiles.first, modelContext: modelContext)
        AutoSweepService.recordActivity(profile: profiles.first, modelContext: modelContext)
    }

    private func verifyPIN(_ pin: String) {
        switch PINService.verify(pin) {
        case .correct:
            pinError = nil
            showingPINPad = false
            isUnlocked = true
        case .duress:
            // Silently wipe everything, then unlock into a fresh, empty app so the
            // wipe is indistinguishable from a brand-new install (priv-3).
            showingPINPad = false
            Task {
                await SecureWipeService.wipeEverything(modelContext: modelContext)
                isUnlocked = true
            }
        case .wrong(let remaining):
            pinError = "Incorrect PIN — \(remaining) attempt\(remaining == 1 ? "" : "s") left."
        case .lockedOut(let retry):
            pinError = "Too many attempts. Try again in \(Int(retry.rounded())) seconds."
        }
    }

    @MainActor
    private func tryUnlock() async {
        guard !attemptingAuth, BiometricService.canAuthenticate else { return }
        attemptingAuth = true
        errorMessage = nil

        // Reset auth state if biometrics hangs for > 30 s.
        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            if attemptingAuth { attemptingAuth = false }
        }
        defer { timeoutTask.cancel() }

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
    let pinAvailable: Bool
    let errorMessage: String?
    let isAuthenticating: Bool
    let onUnlock: () -> Void
    let onUsePIN: () -> Void

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
                         : "Enter your PIN to continue.")
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

                if canAuthenticate {
                    CaelynButton(
                        title: isAuthenticating ? "Unlocking…" : "Unlock with \(primaryLabel)",
                        variant: .primary,
                        icon: primaryIcon
                    ) {
                        onUnlock()
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal, CaelynSpacing.lg)
                }

                if pinAvailable {
                    Button(canAuthenticate ? "Use PIN instead" : "Enter PIN") { onUsePIN() }
                        .font(CaelynFont.body.weight(.medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .padding(.bottom, CaelynSpacing.lg)
                } else {
                    Color.clear.frame(height: 1).padding(.bottom, CaelynSpacing.lg)
                }
            }
        }
    }
}
