import AuthenticationServices
import Foundation
import OSLog

/// The thin layer that actually talks to Apple.
///
/// Everything decidable is decided in `AccountSession` / `AppleSignInOutcome`;
/// this type only turns Apple's callbacks into an `AppleSignInOutcome` and asks
/// after credential state. Keeping it thin is what makes the rest testable.
@MainActor
final class AppleSignInService: NSObject {

    private static let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "account")

    private var continuation: CheckedContinuation<AppleSignInOutcome, Never>?
    /// Held for the duration of one request so ARC doesn't release the controller
    /// (and therefore the delegate) while Apple's sheet is still up.
    private var controller: ASAuthorizationController?

    /// Present Sign in with Apple and wait for the answer.
    ///
    /// Requests `.fullName` and nothing else.
    ///
    /// An earlier draft of this 1.3 work requested `.email` alongside the name and
    /// never once read the value. It was dropped before release, so **no shipped
    /// version of Caelyn has ever asked for an email address** — 1.2 and earlier had
    /// no Sign in with Apple at all, and 1.3 asks only for the name.
    ///
    /// Requesting a scope you do not use is asking someone to hand over an address
    /// for no reason, and it drags an Email Address declaration onto the App Store
    /// privacy label for data the app does not hold.
    ///
    /// Hide My Email is unaffected: it is Apple's choice at the sheet, not something
    /// Caelyn enables by requesting a scope. Dropping `.email` simply means the
    /// relay address is never generated for Caelyn in the first place.
    func signIn() async -> AppleSignInOutcome {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName]

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    /// Ask Apple whether the stored credential is still good.
    ///
    /// Returns `.unknown` on any error, which `AccountSession.reconcile` treats as
    /// "leave her signed in" — an offline launch must never look like a revocation.
    static func credentialState(for userID: String) async -> AppleCredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                let mapped: AppleCredentialState
                switch state {
                case .authorized:       mapped = .authorized
                case .revoked:          mapped = .revoked
                case .notFound:         mapped = .notFound
                case .transferred:      mapped = .unknown
                @unknown default:       mapped = .unknown
                }
                continuation.resume(returning: mapped)
            }
        }
    }

    /// Apple posts this when the user revokes Caelyn from system Settings while the
    /// app is running.
    static var revocationNotification: Notification.Name {
        ASAuthorizationAppleIDProvider.credentialRevokedNotification
    }

    private func finish(_ outcome: AppleSignInOutcome) {
        controller = nil
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failed(reason: "Unexpected credential type"))
            return
        }
        finish(.authorized(
            userID: credential.user,
            givenName: credential.fullName?.givenName,
            familyName: credential.fullName?.familyName
        ))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // A cancellation is a decision, not a failure, and must not surface an
        // error message. Everything else is reported in her language by the caller.
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            finish(.cancelled)
            return
        }
        Self.log.error("Account: authorization error: \(error.localizedDescription, privacy: .public)")
        finish(.failed(reason: error.localizedDescription))
    }
}

// MARK: - Presentation

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
