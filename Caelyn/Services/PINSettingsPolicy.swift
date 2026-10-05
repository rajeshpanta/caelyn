import Foundation

/// When the PIN screen may offer a duress PIN, and when it owes her a warning.
///
/// **Why this is a policy and not an `if` in the view.** A duress PIN is typed
/// into the lock screen, and `AppLockGate` shows no lock screen at all unless
/// App Lock is on — it returns early on `lockEnabled` long before it reaches the
/// PIN pad. So arming a duress PIN with App Lock off produces a wipe that cannot
/// be triggered: the app simply opens.
///
/// That is the worst possible shape for this particular feature. She is told
/// "entering it instead of your real PIN silently and permanently erases
/// everything", she sets it, and the screen confirms it is set — and then in the
/// one situation she armed it for, someone asks her to open the app and it
/// opens. She finds out the feature was never connected at the moment she was
/// relying on it.
///
/// The same hole exists from the other side: switching App Lock off later
/// disconnects a duress PIN that is already armed, silently. So that needs
/// saying out loud rather than leaving her to infer it.
///
/// Kept out of the view so both rules are testable without a UI, and so they
/// cannot drift apart from each other.
enum PINSettingsPolicy {

    /// Whether the "Set a duress PIN" option may be offered.
    ///
    /// Needs both: a real PIN for the duress one to be indistinguishable from
    /// (that was already enforced), and App Lock on, so there is a lock screen to
    /// type it into (that was not).
    static func canArmDuressPIN(lockEnabled: Bool, pinIsSet: Bool) -> Bool {
        lockEnabled && pinIsSet
    }

    /// Why the option is unavailable, in her words. `nil` when it is available.
    static func duressUnavailableReason(lockEnabled: Bool, pinIsSet: Bool) -> String? {
        if !pinIsSet {
            return "Set an App PIN first — a duress PIN works by being typed in place of it."
        }
        if !lockEnabled {
            return "Turn on App Lock first. A duress PIN is typed into the lock screen, so without the lock there's nowhere to enter it."
        }
        return nil
    }

    /// Whether switching App Lock off has to warn her first.
    static func needsDuressWarningWhenDisablingLock(hasDuressPIN: Bool) -> Bool {
        hasDuressPIN
    }

    /// What that warning says. Specific about the consequence, because the
    /// consequence is that a safety feature stops working.
    static let disablingLockWithDuressWarning =
        "Your duress PIN only works from the lock screen. Turn App Lock off and it won't erase anything, because there'll be no PIN to enter."
}
