import Foundation
import SwiftData

/// Auto-erase, stored on this device only.
///
/// **Why it cannot live on the profile.** `autoWipeEnabled`, `autoWipeAfterDays`
/// and `lastActiveAt` were properties of `UserProfile`, and in 1.3 `UserProfile`
/// became a CloudKit-mirrored record. That turned a per-device safety switch into
/// a synced one, which breaks it in both directions:
///
/// She arms auto-erase on her phone because her phone is the device at risk. It
/// syncs to her iPad. The iPad sits in a drawer past the window and wipes itself
/// — and because that store is mirrored too, it exports those deletions to her
/// iCloud, which propagates them back to the phone she uses every day. An
/// inactivity timer on a device she had forgotten about destroys the history on
/// the one in her hand, silently, with nothing on screen either before or after.
///
/// And `lastActiveAt` synced as well, so "last active" meant *any* device. A
/// phone she genuinely lost would keep being counted as active by her iPad, and
/// the window on the lost device would never elapse — the exact case the feature
/// is for.
///
/// Neither of those is fixable while the setting syncs, because the setting is
/// inherently about one piece of hardware: this phone, in this bag, at this
/// risk. So it lives in `UserDefaults`, which is per-device and not mirrored.
///
/// The profile's properties stay in the schema — removing them buys nothing,
/// CloudKit cannot drop a deployed field anyway, and leaving them means
/// `adoptProfileSettingIfNeeded` can carry her existing choice across on the
/// first launch instead of silently disarming something she turned on. They are
/// no longer read by anything else; `AutoSweepService` is the only caller and it
/// reads this.
@MainActor
enum AutoSweepSettings {

    /// Exposed so Settings can observe it with `@AppStorage`. A view cannot see a
    /// plain static over `UserDefaults` change, so the toggle stayed visually off
    /// after she armed it — which for this particular setting reads as "it didn't
    /// work" on the most destructive switch in the app.
    static let enabledKey = Key.enabled

    private enum Key {
        static let enabled = "caelyn.autoWipe.enabled"
        static let afterDays = "caelyn.autoWipe.afterDays"
        static let lastActive = "caelyn.autoWipe.lastActiveAt"
        static let adopted = "caelyn.autoWipe.adoptedFromProfile"
    }

    /// Matches the `UserProfile` default it replaces, so nobody's window changes
    /// length across the handover.
    static let defaultAfterDays = 30

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.enabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.enabled) }
    }

    static var afterDays: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Key.afterDays)
            return stored > 0 ? stored : defaultAfterDays
        }
        set { UserDefaults.standard.set(max(1, newValue), forKey: Key.afterDays) }
    }

    /// When this device last showed her the app. `nil` until the first launch that
    /// records it — which must never read as "infinitely long ago".
    static var lastActiveAt: Date? {
        get { UserDefaults.standard.object(forKey: Key.lastActive) as? Date }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: Key.lastActive) }
            else { UserDefaults.standard.removeObject(forKey: Key.lastActive) }
        }
    }

    /// Carry a choice she made before this was device-local, exactly once.
    ///
    /// Only ever copies *on* — a profile arriving from another device cannot use
    /// this to switch auto-erase off here, and cannot switch it on either, because
    /// it runs once and then never again.
    ///
    /// **A missing profile deliberately burns the one chance.** It would be easy
    /// to wait for a profile to show up instead, and that is the wrong default:
    /// on a fresh install the profile arrives *from iCloud*, carrying a setting
    /// she armed on a different phone — and adopting it here is exactly the
    /// cross-device wipe this type exists to prevent. The case this gives up on
    /// is an upgrading device whose local profile somehow is not loaded yet,
    /// which costs her an auto-erase she must re-arm; the case it refuses is a
    /// device arming itself from somebody else's decision. Losing a destructive
    /// timer is the safer of the two failures.
    static func adoptProfileSettingIfNeeded(_ profile: UserProfile?) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Key.adopted) else { return }
        defaults.set(true, forKey: Key.adopted)
        guard let profile, profile.autoWipeEnabled else { return }
        isEnabled = true
        afterDays = profile.autoWipeAfterDays
        // Her previous activity stamp is the honest starting point: without it, a
        // device that has been idle for weeks would be measured from today and
        // the window she set would be quietly extended.
        lastActiveAt = profile.lastActiveAt
    }

    /// Part of a wipe: the settings are residue too, and a fresh-looking app must
    /// not arrive with a destruct timer already armed.
    static func forget() {
        let defaults = UserDefaults.standard
        for key in [Key.enabled, Key.afterDays, Key.lastActive, Key.adopted] {
            defaults.removeObject(forKey: key)
        }
    }
}
