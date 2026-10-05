import Foundation
import SwiftData

/// Scheduled auto-sweep: an **opt-in, heavily-warned** feature that wipes all data
/// if the app goes untouched for longer than a configured window — for high-threat
/// users who may lose their device. OFF by default; only fires when explicitly
/// enabled (Phase 5 / priv-4). Uses an injectable clock so the window logic is
/// unit-tested without waiting real days.
///
/// Reads `AutoSweepSettings`, not the profile: the window is about one piece of
/// hardware, and the profile syncs. See that type for what went wrong when it
/// didn't.
@MainActor
enum AutoSweepService {

    /// Pure window check (testable): has the inactivity window elapsed?
    static func shouldSweep(autoWipeEnabled: Bool, autoWipeAfterDays: Int,
                            lastActiveAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        guard autoWipeEnabled, autoWipeAfterDays > 0 else { return false }
        let elapsed = calendar.dateComponents([.day], from: lastActiveAt, to: now).day ?? 0
        return elapsed >= autoWipeAfterDays
    }

    /// Call at launch / foreground BEFORE recording activity. Wipes if the window
    /// elapsed. No-op unless the user opted in.
    ///
    /// Returns whether it wiped, because the caller must not then carry on
    /// touching the store as though nothing happened — see `recordActivity`.
    @discardableResult
    static func checkAndSweep(profile: UserProfile?, modelContext: ModelContext, now: Date = .now) async -> Bool {
        // A choice she made before this setting became device-local, carried over
        // once. Must happen before the check, or her armed window is ignored on
        // the very launch that would have honoured it.
        AutoSweepSettings.adoptProfileSettingIfNeeded(profile)

        guard AutoSweepSettings.isEnabled else { return false }
        // No stamp yet means this device has never recorded activity, which is not
        // the same as "idle since 1970". Record and wait.
        guard let lastActive = AutoSweepSettings.lastActiveAt else { return false }

        guard shouldSweep(autoWipeEnabled: true,
                          autoWipeAfterDays: AutoSweepSettings.afterDays,
                          lastActiveAt: lastActive, now: now) else { return false }

        await SecureWipeService.wipeEverything(modelContext: modelContext)
        return true
    }

    /// Stamp the last-active time so the window resets while the app is in use.
    ///
    /// **Never call this after a sweep.** It used to be called unconditionally on
    /// the line after `checkAndSweep`, holding the `profile` the sweep had just
    /// deleted — a write to a deleted `@Model` object, which SwiftData can resolve
    /// by bringing the row back. A resurrected `UserProfile` carries her name, her
    /// cycle averages, her Pro flag and her lock settings, so the wipe that was
    /// meant to leave no trace left the most identifying row in the store — and on
    /// a mirrored container, exported it. `checkAndSweep` returns a Bool so the
    /// caller can tell; `AppLockGate` reads it.
    static func recordActivity(now: Date = .now) {
        AutoSweepSettings.lastActiveAt = now
    }
}
