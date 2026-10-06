import SwiftUI
import SwiftData

struct AppLockGate<Content: View>: View {
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var isUnlocked = false
    @State private var attemptingAuth = false
    @State private var errorMessage: String?
    @State private var showingPINPad = false
    @State private var pinError: String?
    /// Set when a system authentication attempt ends without unlocking — she
    /// cancelled, or it failed. The system sheet makes the scene inactive, so
    /// dismissing it returns the scene to `.active`, and without this the gate
    /// would read that as a fresh return and put the sheet straight back up.
    /// Cancel would never stick, and "Use PIN instead" — the only way to reach
    /// her PIN, or a duress PIN — would be reachable only in the second between
    /// prompts. Cleared by a real trip to the background or by unlocking.
    @State private var holdAutoPrompt = false

    /// Shared with `AppLockWindow`, which draws the lock above presented sheets.
    @State private var lockModel = AppLockModel()
    /// Whether the window took the lock. `@State` rather than reading
    /// `AppLockWindow.isPresenting` directly: that is a plain property, so
    /// changing it does not re-render this view, and the gate went on drawing its
    /// own PIN pad underneath the window's — two live locks, every digit matching
    /// twice.
    @State private var lockInWindow = false

    let content: () -> Content

    /// This device's lock — device-local, so a toggle on another device cannot
    /// switch it off and disconnect a duress PIN armed here. `storedLock` is read
    /// so SwiftUI re-renders when it changes. See `AppLockSettings`.
    @AppStorage(AppLockSettings.key) private var storedLock: Bool?
    ///
    /// Only once she has onboarded. The lock screen already required that, but
    /// the automatic Face ID prompt did not — so a lock setting that outlived its
    /// profile (a store that had to start fresh, a test device) put Face ID up
    /// over "Meet Caelyn", unlocking nothing. Found on a device.
    private var lockEnabled: Bool {
        hasOnboarded && (storedLock ?? AppLockSettings.adopting(profiles.first))
    }
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
                // Opacity hides it from the eye only. Without this the whole app
                // stays in the accessibility tree under the lock window — found
                // on a device, where a test could see the tab bar while locked.
                .accessibilityHidden(showLockScreen)

            // Still drawn here as well as in the window. The window is what puts
            // the lock above presented sheets, but if there is no scene to attach
            // one to this is what she gets — which is exactly the behaviour that
            // shipped before, rather than a blank screen.
            if showLockScreen, !lockInWindow {
                AppLockOverlay(model: lockModel)
            }
        }
        .onAppear {
            syncLockModel()
            // Launching straight into a locked app: `onChange` never fires for a
            // value that was already true.
            if showLockScreen { lockInWindow = AppLockWindow.shared.present(model: lockModel) }
        }
        .onDisappear { AppLockWindow.shared.dismiss(); lockInWindow = false }
        .onChange(of: showLockScreen) { _, locked in
            syncLockModel()
            if locked {
                lockInWindow = AppLockWindow.shared.present(model: lockModel)
            } else {
                AppLockWindow.shared.dismiss()
                lockInWindow = false
            }
        }
        .onChange(of: showPINEntry) { _, _ in syncLockModel() }
        .onChange(of: pinError) { _, _ in syncLockModel() }
        .onChange(of: errorMessage) { _, _ in syncLockModel() }
        .onChange(of: attemptingAuth) { _, _ in syncLockModel() }
        .task { await sweepThenRecordActivity() }   // launch: auto-sweep if the window elapsed
        .task(id: lockEnabled) {
            if lockEnabled && !isUnlocked && BiometricService.canAuthenticate {
                await tryUnlock()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background { holdAutoPrompt = false }
            if newPhase != .active {
                // Relock as soon as Caelyn leaves the active foreground. Some
                // transitions (including app switching and interruptions) can
                // return from `.inactive` without delivering `.background` first.
                isUnlocked = false
                errorMessage = nil
                pinError = nil
                showingPINPad = false
            } else if newPhase == .active {
                Task { await sweepThenRecordActivity() }
                if lockEnabled && !isUnlocked && !attemptingAuth && !holdAutoPrompt
                    && BiometricService.canAuthenticate {
                    Task { await tryUnlock() }
                }
            }
        }
    }

    /// Push the gate's state into the model the window renders from, and hand it
    /// the actions. Called whenever anything the lock displays changes.
    private func syncLockModel() {
        lockModel.showPINEntry = showPINEntry
        lockModel.pinError = pinError
        lockModel.biometricError = errorMessage
        lockModel.isAuthenticating = attemptingAuth
        lockModel.biometricKind = BiometricService.availableKind()
        lockModel.canAuthenticate = BiometricService.canAuthenticate
        lockModel.pinAvailable = PINService.isSet
        lockModel.onUnlock = { Task { await tryUnlock() } }
        lockModel.onUsePIN = { showingPINPad = true; pinError = nil }
        lockModel.onSubmitPIN = { verifyPIN($0) }
        lockModel.onCancelPIN = BiometricService.canAuthenticate
            ? { showingPINPad = false; pinError = nil } : nil
    }

    private var showLockScreen: Bool {
        guard hasOnboarded, lockEnabled else { return false }
        // Fail OPEN if there's no way to unlock (no biometrics AND no PIN) — a user
        // must never be permanently locked out of their own data.
        guard BiometricService.canAuthenticate || PINService.isSet else { return false }
        // Cover whenever locked OR the app isn't active, so the app-switcher
        // snapshot never exposes content.
        return !isUnlocked || scenePhase != .active
    }

    /// Run the opt-in auto-sweep using the PREVIOUS activity timestamp, then stamp
    /// the new one. No-op unless the user enabled auto-wipe (priv-4).
    ///
    /// The stamp is skipped when the sweep actually fired. It used to run either
    /// way, writing to the `UserProfile` the sweep had just deleted — which can
    /// bring the row back, leaving her name, averages and settings in a store that
    /// was supposed to look brand new.
    @MainActor
    private func sweepThenRecordActivity() async {
        let wiped = await AutoSweepService.checkAndSweep(profile: profiles.first, modelContext: modelContext)
        guard !wiped else { return }
        AutoSweepService.recordActivity()
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
            holdAutoPrompt = false
        } catch BiometricError.userCancelled {
            // user dismissed — leave them at the lock screen, and keep them there
            holdAutoPrompt = true
        } catch BiometricError.systemCancelled {
            // The prompt was withdrawn because she left the app. That arrives
            // after the trip to the background, so holding here would swallow
            // the prompt she is owed when she comes back.
        } catch {
            errorMessage = error.localizedDescription
            holdAutoPrompt = true
        }
        attemptingAuth = false
    }
}

struct AppLockScreen: View {
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
