import Foundation
import OSLog
import SwiftData

/// Applies account outcomes to the two places identity is allowed to live: the
/// Keychain (the credential) and `UserProfile` (the name she's greeted by).
///
/// **The rule this type exists to enforce:** nothing here ever deletes a
/// `CycleEntry`. Signing in, signing out, a revoked credential, a failed
/// authorization — all of them touch identity only. Her history is not a
/// possession of her account, and losing an account must never look like losing a
/// year of tracking.
@MainActor
enum AccountSession {

    private static let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "account")

    // MARK: - Signing in

    /// Record a successful authorization.
    ///
    /// The name is written **once and only if she has not already chosen one**.
    /// Apple returns the name on the first authorization and never again, so it is
    /// persisted immediately; but a `preferredName` she typed herself always wins,
    /// and re-authorizing must not quietly reset it back to what Apple said.
    @discardableResult
    static func apply(_ outcome: AppleSignInOutcome, to profile: UserProfile?) -> Bool {
        switch outcome {
        case let .authorized(userID, givenName, familyName):
            AccountIdentityStore.save(appleUserID: userID)
            profile?.accountLinked = true

            // Apple's name is a suggestion, captured on the one occasion it is
            // offered. `PersonalName.fromApple` drops anything unusable, so a
            // Hide My Email relay address can never land in a greeting.
            if let suggested = PersonalName.fromApple(givenName: givenName, familyName: familyName) {
                if profile?.appleSuggestedName == nil {
                    profile?.appleSuggestedName = suggested
                }
                // Seed the preferred name only when she has none, so the first
                // greeting after signing in already knows her.
                if PersonalName.usable(profile?.preferredName) == nil {
                    profile?.preferredName = suggested
                }
            }
            log.info("Account: linked.")
            return true

        case .cancelled:
            // She changed her mind. Nothing happened, and nothing should be said
            // about it beyond returning her to where she was.
            return false

        case let .failed(reason):
            log.error("Account: sign-in failed: \(reason, privacy: .public)")
            return false
        }
    }

    // MARK: - Signing out

    /// Unlink the Apple identity. **Keeps every entry, and keeps her name.**
    ///
    /// The name survives on purpose: she chose it, it is a preference like the
    /// first day of the week, and a home screen that stops knowing her the moment
    /// she signs out would read as data loss even though nothing was lost. She can
    /// clear it herself in Settings.
    static func signOut(profile: UserProfile?) {
        AccountIdentityStore.signOut()
        profile?.accountLinked = false
        log.info("Account: signed out; cycle history untouched.")
    }

    /// React to a credential-state check.
    ///
    /// Returns true when the session ended. An `.unknown` state — the offline case —
    /// deliberately changes nothing.
    @discardableResult
    static func reconcile(_ state: AppleCredentialState, profile: UserProfile?) -> Bool {
        switch state.action {
        case .staySignedIn:
            return false
        case .signOutLocally:
            guard AccountIdentityStore.isSignedIn else { return false }
            signOut(profile: profile)
            log.info("Account: credential revoked at Apple; local session ended, history intact.")
            return true
        }
    }

    // MARK: - Name

    /// Set or clear the name Caelyn greets her by.
    ///
    /// An empty or unusable string clears it rather than storing junk, so the
    /// greeting falls back to the warm nameless version instead of rendering a
    /// blank gap after a comma.
    static func setPreferredName(_ raw: String?, on profile: UserProfile?) {
        profile?.preferredName = PersonalName.usable(raw)
    }
}
