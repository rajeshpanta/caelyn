import Foundation

/// When the post-onboarding account offer is due — and, more importantly, why the
/// answer must never be wired straight to the sheet's `isPresented`.
///
/// **The bug this type exists to prevent.** The offer is due while she has neither
/// answered it nor linked an account. Signing in sets `accountLinked = true`, so the
/// instant Apple returns a credential the condition goes false. When the sheet was
/// presented directly from that condition, SwiftUI tore it down *mid-flow* — before
/// `AccountOfferSheet` could present "What should Caelyn call you?". The failure was
/// completely silent: she authorised with Face ID, landed on the home screen, and
/// was never asked her name, so the one feature the offer exists to deliver never
/// happened.
///
/// The rule, therefore: **this condition may raise the sheet, but only an explicit
/// dismissal may lower it.** A raise-only latch keeps the sheet alive for the whole
/// conversation, including the name step that runs after a successful sign-in.
enum AccountOfferPolicy {

    /// Whether the offer should be raised now.
    ///
    /// Gated on `hasOnboarded` so it lands *after* onboarding, over an app she can
    /// already use, rather than reading as a sign-up wall in front of a period
    /// tracker.
    static func isDue(hasOnboarded: Bool, hasSeenAccountOffer: Bool, accountLinked: Bool) -> Bool {
        guard hasOnboarded else { return false }
        return !hasSeenAccountOffer && !accountLinked
    }

    @MainActor
    static func isDue(for profile: UserProfile?) -> Bool {
        guard let profile else { return false }
        return isDue(
            hasOnboarded: profile.hasOnboarded,
            hasSeenAccountOffer: profile.hasSeenAccountOffer,
            accountLinked: profile.accountLinked
        )
    }
}
