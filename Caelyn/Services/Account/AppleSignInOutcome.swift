import Foundation

/// What came back from an attempt to sign in with Apple, reduced to the shape
/// Caelyn actually reasons about.
///
/// Kept separate from `ASAuthorizationController` so every rule below — which name
/// wins, what a cancellation means, what happens to her history — can be tested
/// without a device, a signing certificate, or a real Apple Account.
enum AppleSignInOutcome: Equatable {
    /// Apple authorized. `givenName`/`familyName` are populated **only on the very
    /// first authorization** for this app; every later sign-in returns nil for both,
    /// which is why the name has to be persisted the moment it arrives.
    case authorized(userID: String, givenName: String?, familyName: String?)
    /// She backed out. Not an error, and nothing should look like one.
    case cancelled
    /// Something genuinely failed — no network, Apple unreachable, an unknown error.
    case failed(reason: String)
}

/// The credential's standing with Apple, checked on launch and on foregrounding.
enum AppleCredentialState: Equatable {
    case authorized
    /// She revoked Caelyn in Settings → Apple Account → Sign in with Apple, or
    /// signed out of the device entirely.
    case revoked
    /// Apple has no record of this identifier — treated exactly like revoked.
    case notFound
    /// Couldn't reach Apple. **Not** a reason to sign anybody out: an offline
    /// launch must never look like a revocation.
    case unknown
}

/// What Caelyn should do about a credential state, decided in one place.
///
/// The only outcome that ends a session is an unambiguous answer from Apple that
/// the credential is gone. Everything else leaves her signed in, because the
/// alternative — signing her out because a train went into a tunnel — is both
/// alarming and wrong.
enum AccountAction: Equatable {
    case staySignedIn
    case signOutLocally
}

extension AppleCredentialState {
    var action: AccountAction {
        switch self {
        case .authorized, .unknown: return .staySignedIn
        case .revoked, .notFound:   return .signOutLocally
        }
    }
}
