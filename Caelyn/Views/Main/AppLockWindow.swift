import SwiftUI
import UIKit

/// The live state of the lock screen, shared between `AppLockGate` and the
/// window that actually draws it.
///
/// A plain `@Observable` rather than view state because the lock is rendered
/// outside the gate's own view hierarchy — see `AppLockWindow` for why it has
/// to be.
@MainActor
@Observable
final class AppLockModel {
    var showPINEntry = false
    var pinError: String?
    var biometricError: String?
    var isAuthenticating = false
    var biometricKind: BiometricKind = .none
    var canAuthenticate = false
    var pinAvailable = false

    /// Supplied by the gate, which owns the actual unlock logic.
    var onUnlock: () -> Void = {}
    var onUsePIN: () -> Void = {}
    var onSubmitPIN: (String) -> Void = { _ in }
    var onCancelPIN: (() -> Void)?
}

/// Draws the lock in a `UIWindow` of its own, above everything else on screen.
///
/// **Why a separate window.** The lock used to be a sibling in the gate's
/// `ZStack`, hiding the app by setting the content's opacity to zero. That works
/// for the content — and only for the content. A `.sheet` is not part of that
/// hierarchy: UIKit presents it in its own layer above the entire SwiftUI tree,
/// so the opacity never reaches it and neither does the lock screen drawn beside
/// it.
///
/// The result was that anything she had open when Caelyn locked stayed on screen,
/// fully readable and fully interactive, on top of a lock screen that believed it
/// was covering the app: the day detail with her flow and symptoms on it, an
/// export of her whole history, the paywall, her import. Someone picking up her
/// phone got exactly the thing App Lock exists to prevent, and the lock screen
/// behind it made it look deliberate. A UI test pins this.
///
/// A window at `.alert + 1` sits above presented view controllers, so it covers
/// sheets, alerts and the app-switcher snapshot alike, and it does it without
/// every sheet in the app having to know the lock exists.
///
/// **It must never be able to strand her.** The window is created only while the
/// lock is up and torn down the moment it is not; `AppLockGate` keeps rendering
/// its own in-hierarchy lock as well, so if there is no scene to attach to — and
/// in a unit-test host there is not — the behaviour falls back to exactly what it
/// was before rather than to an empty screen.
@MainActor
final class AppLockWindow {

    static let shared = AppLockWindow()
    private init() {}

    private var window: UIWindow?

    /// Whether the window is currently carrying the lock. The gate reads this to
    /// decide whether its own copy still needs to draw.
    private(set) var isPresenting = false

    /// Put the lock up. Returns whether it worked — `false` means no window scene
    /// was available and the caller's in-hierarchy lock is doing the job.
    @discardableResult
    func present(model: AppLockModel) -> Bool {
        if window != nil { return true }
        guard let scene = Self.activeScene() else { return false }

        let host = UIHostingController(rootView: AppLockOverlay(model: model))
        host.view.backgroundColor = UIColor(CaelynColor.backgroundCream)

        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        // Above presented sheets and alerts, below the system status bar.
        window.windowLevel = .alert + 1
        // So VoiceOver cannot reach the app behind the lock.
        window.accessibilityViewIsModal = true
        // Visible but deliberately not key: the lock needs touches, which any
        // visible window at a higher level receives, and leaving the app's own
        // window key means dismissing this one cannot leave the app without one.
        window.isHidden = false

        self.window = window
        isPresenting = true
        return true
    }

    func dismiss() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        isPresenting = false
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
            ?? scenes.first
    }
}

/// What the lock window draws: the PIN pad, or the biometric lock screen.
///
/// Identical in content to what the gate rendered inline, so moving it here
/// changed where the lock lives and nothing about what she sees.
struct AppLockOverlay: View {
    @Bindable var model: AppLockModel

    var body: some View {
        Group {
            if model.showPINEntry {
                PINPadView(
                    title: "Enter PIN",
                    subtitle: "Unlock Caelyn",
                    length: 4,
                    errorMessage: model.pinError,
                    onSubmit: model.onSubmitPIN,
                    onCancel: model.onCancelPIN
                )
                .background(CaelynColor.backgroundCream.ignoresSafeArea())
            } else {
                AppLockScreen(
                    biometricKind: model.biometricKind,
                    canAuthenticate: model.canAuthenticate,
                    pinAvailable: model.pinAvailable,
                    errorMessage: model.biometricError,
                    isAuthenticating: model.isAuthenticating,
                    onUnlock: model.onUnlock,
                    onUsePIN: model.onUsePIN
                )
            }
        }
    }
}
