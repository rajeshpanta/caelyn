import Foundation

/// Whether App Lock is on — for *this device*, and only this device.
///
/// **Why it left the synced profile.** `UserProfile.lockEnabled` is mirrored to
/// iCloud. Switching App Lock off on her iPad therefore switched it off on her
/// phone too — and the lock screen is the only place a duress PIN can be typed.
/// The phone's duress PIN, which lives in this device's Keychain, was disconnected
/// without the warning she gets when she turns the lock off on the phone itself,
/// and without her ever looking at the phone. A lock is a property of the device
/// in her hand, the same way auto-erase is (`AutoSweepSettings`).
///
/// **Adoption.** A device that has never decided adopts the profile's value the
/// first time it is read *with a profile present*, synchronously, so an upgrading
/// user whose lock was on is locked from the very first frame. After that the
/// profile is never read again here, and nothing here writes it.
enum AppLockSettings {

    /// The seeded demo store (screenshots, UI tests) gets keys of its own, reset
    /// every launch — exactly as when the lock lived on its in-memory profile. A
    /// real lock must never leak into a demo launch, nor a demo one into hers.
    static let key = Persistence.isDemoStore ? "caelyn.lock.enabled.demo" : "caelyn.lock.enabled"
    /// Set once this device has adopted — and kept across a wipe, so a profile
    /// still on screen as the wipe lands, or one that syncs back in later, can
    /// never re-lock the app she was handed back.
    private static let adoptedKey = Persistence.isDemoStore
        ? "caelyn.lock.adoptedFromProfile.demo" : "caelyn.lock.adoptedFromProfile"

    /// This device's setting, adopting the profile's on first read.
    static func isEnabled(profile: UserProfile?) -> Bool {
        if let stored = UserDefaults.standard.object(forKey: key) as? Bool { return stored }
        return adopting(profile)
    }

    /// Record the profile's value as this device's, if there is a profile yet.
    /// With none — first launch, mid-onboarding — nothing is decided or stored.
    @discardableResult
    static func adopting(_ profile: UserProfile?) -> Bool {
        let defaults = UserDefaults.standard
        guard let profile, !defaults.bool(forKey: adoptedKey) else { return false }
        defaults.set(true, forKey: adoptedKey)
        defaults.set(profile.lockEnabled, forKey: key)
        return profile.lockEnabled
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: key)
    }

    /// Part of a wipe: the app she is handed back must open unlocked and new.
    static func forget() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// The demo store starts from nothing on every launch; so does its lock.
    static func resetIfDemoStore() {
        guard Persistence.isDemoStore else { return }
        resetForTesting()
    }

    /// For tests: forget everything, adoption included.
    static func resetForTesting() {
        forget()
        UserDefaults.standard.removeObject(forKey: adoptedKey)
    }
}
