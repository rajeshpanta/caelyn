import Foundation
import SwiftData

/// Scheduled auto-sweep: an **opt-in, heavily-warned** feature that wipes all data
/// if the app goes untouched for longer than a configured window — for high-threat
/// users who may lose their device. OFF by default; only fires when explicitly
/// enabled (Phase 5 / priv-4). Uses an injectable clock so the window logic is
/// unit-tested without waiting real days.
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
    static func checkAndSweep(profile: UserProfile?, modelContext: ModelContext, now: Date = .now) async {
        guard let profile else { return }
        if shouldSweep(autoWipeEnabled: profile.autoWipeEnabled,
                       autoWipeAfterDays: profile.autoWipeAfterDays,
                       lastActiveAt: profile.lastActiveAt, now: now) {
            await SecureWipeService.wipeEverything(modelContext: modelContext)
        }
    }

    /// Stamp the last-active time so the window resets while the app is in use.
    static func recordActivity(profile: UserProfile?, modelContext: ModelContext, now: Date = .now) {
        guard let profile else { return }
        profile.lastActiveAt = now
        modelContext.saveOrLog()
    }
}
