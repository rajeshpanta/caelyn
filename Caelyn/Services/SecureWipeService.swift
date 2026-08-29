import Foundation
import SwiftData
import WidgetKit

/// Orchestrates a **complete** local wipe of everything Caelyn stores. Used by
/// "Delete all data" today, and the foundation for the duress / secure-wipe
/// privacy feature later. Every storage location must be purged here, or a
/// "delete" would leave residue (Phase 5 / priv-3).
///
/// Storage locations:
///  1. SwiftData store — all CycleEntry + UserProfile rows
///  2. Pending local notifications (would otherwise fire referencing gone data)
///  3. Apple Health — only the flow/symptom/pain samples Caelyn itself wrote
///  4. App-Group widget snapshot (so widgets/watch stop showing data)
///  5. App preference flags that could leak state or re-show stale UI
@MainActor
enum SecureWipeService {

    /// How far a wipe reaches.
    ///
    /// Made explicit in 1.3 because "delete everything" stopped having one obvious
    /// meaning the moment a cloud copy could exist. Nothing may guess: the caller
    /// states the scope, and the UI states it to her in the same words.
    enum Scope: Equatable {
        /// Everything on this iPhone. A cloud copy, if she has one, is left alone —
        /// and the caller is responsible for saying so.
        case thisDevice
        /// This iPhone *and* the private iCloud copy.
        case thisDeviceAndCloud
    }

    /// Wipe local storage, and optionally the iCloud copy first.
    ///
    /// **Cloud goes first, deliberately.** If the app dies mid-wipe, the safe half
    /// to have completed is the one that removes data from a server: an interrupted
    /// wipe then leaves history on a phone she is holding, rather than an untouched
    /// copy in iCloud she believes is gone. Returns the cloud outcome so the caller
    /// can report honestly instead of assuming.
    @discardableResult
    static func wipeEverything(
        modelContext: ModelContext,
        scope: Scope = .thisDevice
    ) async -> CloudDataDeletion.Outcome? {
        var cloudOutcome: CloudDataDeletion.Outcome?
        if scope == .thisDeviceAndCloud {
            cloudOutcome = await CloudDataDeletion.deleteCloudCopy()
        }

        // 1. SwiftData — batch-delete every row of each model.
        try? modelContext.delete(model: CycleEntry.self)
        try? modelContext.delete(model: UserProfile.self)
        modelContext.saveOrLog()

        // 2. Cancel all pending/legacy notifications.
        await NotificationService.cancelAll()

        // 3. Remove Caelyn-authored Apple Health samples (no-op if not connected).
        await HealthKitService.deleteAllOwnSamples()

        // 4. Clear the shared widget snapshot and force widgets/watch to refresh.
        WidgetDataStore.clear()
        WidgetCenter.shared.reloadAllTimelines()

        // 5. Remove app-lock secrets and failed-attempt state from the Keychain.
        PINService.clearAll()

        // 5b. Drop the Apple Health provenance ledger and sync anchors. They hold
        //     no readings, but they do record which days carried which kinds of
        //     data — that is residue, and a wipe must not leave residue.
        HealthSyncService.forgetSyncState()

        // 6. Reset preference flags so the next onboarding is genuinely fresh.
        let defaults = UserDefaults.standard
        for key in [
            "caelyn.dismissedInsights",
            // Retired flags remain here so upgrades also remove old state.
            "caelyn.softPaywallShown",
            "caelyn.firstPredictionCelebrated",
            "caelyn.periodRecapDismissedFor",
            "caelyn.firstFlowCelebrated",
            "caelyn.firstWeekCelebrated",
            "caelyn.seenIntro.home",
            "caelyn.seenIntro.calendar",
            "caelyn.seenIntro.log",
            "caelyn.seenIntro.insights",
            "caelyn.seenIntro.settings",
            "caelyn.seenLearnedLuteal",
            "caelyn.seenLearnedPms",
            Persistence.syncEnabledKey,
            Persistence.storeFailedKey
            // NOT CloudDataDeletion.deletedAtKey — see the note at the end.
        ] {
            defaults.removeObject(forKey: key)
        }
        RatingService.reset()

        // The deletion marker is deliberately NOT cleared here. It is the record
        // that she chose to destroy a cloud copy, and it is what stops a later
        // launch quietly rebuilding one.
        return cloudOutcome
    }
}
