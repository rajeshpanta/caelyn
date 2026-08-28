import CloudKit
import Foundation
import OSLog

/// Permanently removing the private iCloud copy of her history.
///
/// **Why this is a direct CloudKit operation and not "delete the rows and let sync
/// carry it".** Mirrored deletions are asynchronous. If Caelyn deleted every local
/// row, turned sync off, and the app were killed a second later, the deletions
/// would never finish uploading — the cloud copy would survive intact, and
/// re-enabling sync months later would pour it all back. Deleting the record zone
/// outright is a single server-side operation whose success is something Caelyn can
/// actually check, which is the only version of "permanently deleted" worth telling
/// someone about their reproductive health.
///
/// This deletes **only** the cloud copy. Local history is not touched here, ever.
@MainActor
enum CloudDataDeletion {

    private static let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "clouddelete")

    /// The zone SwiftData/Core Data mirrors into. Everything Caelyn ever puts in
    /// CloudKit lives here, so removing it removes the entire cloud copy.
    static let mirroredZoneName = "com.apple.coredata.cloudkit.zone"

    /// Set the moment a deletion starts, cleared only when it is confirmed.
    ///
    /// If the app dies mid-deletion this survives, and the next launch can say "that
    /// didn't finish" instead of showing a reassuring screen over a cloud copy that
    /// is still there.
    static let pendingKey = "caelyn.cloudDeletionPending"

    /// When she last deliberately destroyed the cloud copy.
    ///
    /// This is the resurrection guard. While it is set, sync stays off until she
    /// turns it back on herself, and every launch re-checks that the zone has not
    /// come back — because a live mirroring delegate can recreate a zone it is
    /// still attached to.
    static let deletedAtKey = "caelyn.cloudCopyDeletedAt"

    /// Set the first time the mirrored store actually opens, and cleared only by a
    /// confirmed deletion.
    ///
    /// **Sync being off is not proof that no cloud copy exists.** Someone who
    /// synced for a month and then switched sync off still has a month of history
    /// sitting in iCloud, and hiding the delete action from her — which is what
    /// Caelyn did until this flag existed — leaves her no way to remove it short of
    /// turning sync back on. This records "a copy may be out there" independently
    /// of whether Caelyn is currently syncing.
    ///
    /// Written only when `isSyncActive` becomes true, never merely when she flips
    /// the preference: if the container never opened, nothing was ever uploaded and
    /// offering to delete a copy that cannot exist would be its own small lie.
    static let mayExistKey = "caelyn.cloudCopyMayExist"

    static var deletionIsPending: Bool { UserDefaults.standard.bool(forKey: pendingKey) }
    static var cloudCopyWasDeleted: Bool { UserDefaults.standard.object(forKey: deletedAtKey) != nil }

    /// True when Caelyn has reason to believe a private cloud copy exists.
    static var cloudCopyMayExist: Bool { UserDefaults.standard.bool(forKey: mayExistKey) }

    /// Record that the mirrored store opened, so a copy is presumed to exist from
    /// here until she deletes it. Idempotent.
    static func noteCloudCopyMayExist() {
        UserDefaults.standard.set(true, forKey: mayExistKey)
    }

    enum Outcome: Equatable {
        /// The zone is gone, confirmed by the server.
        case deleted
        /// There was nothing in iCloud to delete. Still a success.
        case nothingToDelete
        /// iCloud could not be reached. **Nothing was deleted**, and the copy is
        /// still there — this must never be reported as success.
        case unavailable(CloudAvailability)
        /// The attempt failed. The pending marker stays set so it can be retried.
        case failed
    }

    /// Permanently delete the private iCloud copy.
    ///
    /// Order matters. Sync is switched off *first* so the live mirror stops treating
    /// the local store as something to re-upload; then the zone goes. The deletion
    /// marker is written before the network call, so an interruption is recoverable
    /// rather than invisible.
    static func deleteCloudCopy() async -> Outcome {
        let availability = await CloudAccount.availability()
        guard availability == .available else {
            log.warning("Cloud delete: iCloud unavailable; nothing was deleted.")
            return .unavailable(availability)
        }

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: pendingKey)
        // Stop sync before removing the zone, so the mirror is not simultaneously
        // trying to push the local store back up into it.
        defaults.set(false, forKey: Persistence.syncEnabledKey)

        do {
            let database = CKContainer(identifier: Persistence.cloudKitContainerID).privateCloudDatabase
            let zoneID = CKRecordZone.ID(zoneName: mirroredZoneName, ownerName: CKCurrentUserDefaultName)
            _ = try await database.modifyRecordZones(saving: [], deleting: [zoneID])

            let deletedAt = Date()
            defaults.set(deletedAt, forKey: deletedAtKey)
            defaults.removeObject(forKey: pendingKey)
            defaults.removeObject(forKey: mayExistKey)
            // Tell her other devices, or they will recreate the zone and upload
            // their own copy the next time they open. The tombstone lives in the
            // default zone, which deleting the mirrored zone does not touch.
            await CloudDeletionTombstone.write(deletedAt: deletedAt)
            log.info("Cloud delete: private iCloud copy removed.")
            return .deleted
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            // Already gone. Recording the marker anyway is correct: the outcome she
            // asked for is the outcome she has.
            let deletedAt = Date()
            defaults.set(deletedAt, forKey: deletedAtKey)
            defaults.removeObject(forKey: pendingKey)
            defaults.removeObject(forKey: mayExistKey)
            await CloudDeletionTombstone.write(deletedAt: deletedAt)
            log.info("Cloud delete: there was no iCloud copy to remove.")
            return .nothingToDelete
        } catch {
            // Pending stays set on purpose so the next launch retries and the UI
            // keeps telling the truth in the meantime.
            log.error("Cloud delete failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    /// Finish or re-assert a deletion at launch.
    ///
    /// Covers the two ways a cloud copy could come back after she destroyed it: an
    /// interrupted deletion that never completed, and a mirroring delegate that
    /// recreated the zone before it was detached. Both are resolved by deleting
    /// again, which is safe because the operation is idempotent.
    @discardableResult
    static func resolveOutstandingDeletion() async -> Outcome? {
        guard deletionIsPending || cloudCopyWasDeleted else { return nil }
        // If she has deliberately turned sync back on since, she has changed her
        // mind and is entitled to a fresh cloud copy. Do not fight her.
        guard !Persistence.isSyncEnabled else {
            UserDefaults.standard.removeObject(forKey: deletedAtKey)
            UserDefaults.standard.removeObject(forKey: pendingKey)
            return nil
        }
        return await deleteCloudCopy()
    }

    /// Forget that a deletion ever happened — used when she knowingly re-enables
    /// sync and accepts that a new cloud copy will be created from this device.
    static func clearDeletionMarker() {
        UserDefaults.standard.removeObject(forKey: deletedAtKey)
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    /// She has deliberately switched sync on. Record the consent locally and lift
    /// the tombstone, so neither this device nor any other keeps standing sync
    /// down over a decision she has since reversed.
    static func recordSyncConsentAndLiftTombstone() {
        clearDeletionMarker()
        CloudDeletionTombstone.recordSyncConsent()
        Task { await CloudDeletionTombstone.clear() }
    }

    /// Honour a deletion performed on another device.
    ///
    /// Returns true when this device stood down. Mirroring may already have
    /// recreated the zone by the time this runs, so the copy is removed again as
    /// well as sync being switched off — the end state is the one she asked for.
    @discardableResult
    static func honourRemoteDeletionIfNeeded() async -> Bool {
        let tombstone = await CloudDeletionTombstone.fetch()
        guard CloudDeletionTombstone.verdict(
            tombstone: tombstone,
            localConsent: CloudDeletionTombstone.localConsent
        ) == .honourDeletion else { return false }

        log.info("Cloud delete: honouring a deletion made on another device.")
        UserDefaults.standard.set(false, forKey: Persistence.syncEnabledKey)
        _ = await deleteCloudCopy()
        return true
    }
}

extension CloudDataDeletion.Outcome {
    /// What she is told. Never a CKError, and never "deleted" unless it was.
    var message: String {
        switch self {
        case .deleted:
            return "Your iCloud copy has been permanently deleted. What's on this iPhone is untouched."
        case .nothingToDelete:
            return "There was nothing stored in iCloud. What's on this iPhone is untouched."
        case let .unavailable(availability):
            return "Nothing was deleted \u{2014} Caelyn couldn't reach iCloud. \(availability.message)"
        case .failed:
            return "That didn't finish, so your iCloud copy may still be there. Caelyn will try again next time you open it."
        }
    }

    /// True only when the cloud copy is genuinely gone.
    var didDelete: Bool {
        switch self {
        case .deleted, .nothingToDelete: return true
        case .unavailable, .failed:      return false
        }
    }
}
