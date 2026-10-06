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
        /// Everything on this iPhone.
        ///
        /// **Only safe to offer when no cloud copy can exist.** If the running
        /// `Persistence.live` opened mirrored, these deletions belong to the mirror
        /// and it will export them — so this scope is not "local" in that state.
        /// `deleteAllOffer(mayHaveCloudCopy:)` is what keeps it off the screen then.
        case thisDevice
        /// This iPhone *and* the private iCloud copy.
        case thisDeviceAndCloud
    }

    /// What the "Delete all data" dialog is allowed to offer.
    ///
    /// **Why a local-only delete is withheld while a cloud copy may exist.**
    /// `Persistence.live` is built once per launch. When it opened with CloudKit
    /// mirroring, it stays mirrored for the whole process: switching the sync
    /// preference off writes a `UserDefaults` flag that is only read the *next*
    /// time the container is built. So a "this iPhone only" wipe would delete rows
    /// on a live mirrored store, and those deletions are the mirror's to export —
    /// to her iCloud, and from there to every other device she owns.
    ///
    /// Caelyn cannot truthfully promise that deletion stays local, so it does not
    /// offer it. The both-places delete is retained because it is the one that
    /// already does exactly what its label says, and Cancel is always there.
    /// A genuine local-only wipe needs the container torn down and reopened
    /// unmirrored; that is a deliberate future piece of work, not a label change.
    enum DeleteAllOffer: Equatable {
        /// No cloud copy can exist, so a plain local wipe is safe and truthful.
        case deviceOnly
        /// A cloud copy may exist: only the device-and-iCloud wipe is offered.
        case deviceAndCloudOnly

        /// True when the dialog may show a delete that claims to stay on this device.
        var offersLocalOnlyDelete: Bool { self == .deviceOnly }
    }

    /// The single rule behind the dialog, exposed so it can be tested without a UI.
    static func deleteAllOffer(mayHaveCloudCopy: Bool) -> DeleteAllOffer {
        mayHaveCloudCopy ? .deviceAndCloudOnly : .deviceOnly
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

        // 4b. And tell the watch, which does not read that snapshot. Its copy
        //     arrives over WatchConnectivity, whose application context is
        //     persistent — so clearing the phone's store left her cycle day and
        //     next predicted period on her wrist, surviving a relaunch of the
        //     watch app. A delete that leaves her data on a device she is wearing
        //     has not deleted her data.
        WatchBridgeService.shared.pushCleared()

        // 5. Remove app-lock secrets and failed-attempt state from the Keychain.
        PINService.clearAll()

        // 5b. Drop the Apple Health provenance ledger and sync anchors. They hold
        //     no readings, but they do record which days carried which kinds of
        //     data — that is residue, and a wipe must not leave residue.
        HealthSyncService.forgetSyncState()

        // 5c. Forget who she is. The Apple user identifier lives in its own
        //     Keychain item precisely so signing out does not touch her history —
        //     but this is the opposite operation. "Everything on this iPhone was
        //     deleted" is not true while the app still knows her account, and for
        //     the duress wipe an app that opens already signed in is the single
        //     most visible sign that something was here.
        AccountIdentityStore.signOut()

        // 5d. Disarm auto-erase. Otherwise the fresh-looking app she is handed
        //     back has a destruct timer already running on it.
        AutoSweepSettings.forget()
        AppLockSettings.forget()

        // 5e. Files. Three kinds, all of them her history in full:
        //
        //     • Exports. `ExportService` writes a CSV or PDF of everything she has
        //       logged into the temporary directory to hand to the share sheet. iOS
        //       clears that directory eventually, on its own schedule — so a share
        //       she started and cancelled can sit there in plaintext long after she
        //       has asked for everything to be deleted.
        //     • Preserved stores. When a store cannot be opened,
        //       `Persistence.preserveStoreAside` renames it rather than discard it,
        //       which is right — it may be recoverable. It is also a complete
        //       SQLite copy of her history that nothing deletes and no screen
        //       offers her.
        //     • The import ledger. It holds no readings, but it records which days
        //       carried which fields, which is enough to reconstruct the shape of
        //       her cycle.
        removeStoredFiles()

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
        // "Backed up … last updated" is a claim about a copy of her history. After
        // a wipe there is no history to have backed up.
        CloudSyncHealth.shared.forget()

        // The deletion marker is deliberately NOT cleared here. It is the record
        // that she chose to destroy a cloud copy, and it is what stops a later
        // launch quietly rebuilding one.
        return cloudOutcome
    }

    /// Every file Caelyn has written that could still hold her history.
    ///
    /// Exposed for tests, which seed each kind into a scratch directory and check
    /// it is gone. Failures are swallowed deliberately: a file that cannot be
    /// removed must not abort a wipe half way and leave the rest behind.
    static func removeStoredFiles(
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        applicationSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    ) {
        let fm = FileManager.default

        // Exports: `Caelyn-all-2026-10-05.csv`, `Caelyn-3mo-….pdf`, and so on.
        if let files = try? fm.contentsOfDirectory(at: temporaryDirectory,
                                                   includingPropertiesForKeys: nil) {
            for url in files where url.lastPathComponent.hasPrefix("Caelyn-") {
                try? fm.removeItem(at: url)
            }
        }

        guard let applicationSupport else { return }

        // Preserved stores — `default.store.corrupt-<stamp>` plus its `-shm` and
        // `-wal` sidecars — and the import ledger, which lives alongside them.
        if let files = try? fm.contentsOfDirectory(at: applicationSupport,
                                                   includingPropertiesForKeys: nil) {
            for url in files where url.lastPathComponent.contains(".corrupt-") {
                try? fm.removeItem(at: url)
            }
        }
        try? fm.removeItem(at: applicationSupport.appending(path: "CaelynImportLedger.json"))
    }
}
