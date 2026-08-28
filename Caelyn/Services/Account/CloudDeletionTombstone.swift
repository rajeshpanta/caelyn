import CloudKit
import Foundation
import OSLog

/// Makes "delete my iCloud copy" mean it on *every* device, not just this one.
///
/// **The hole this closes.** Every deletion marker Caelyn keeps lives in
/// `UserDefaults.standard`, which is device-local. So when she deletes the cloud
/// copy on her phone, her iPad knows nothing about it: it still has sync switched
/// on, it opens its mirrored store, CloudKit finds the zone missing, and
/// `NSPersistentCloudKitContainer` helpfully recreates it and uploads the iPad's
/// entire history back. Reproductive-health data she deliberately destroyed
/// reappears, with no decision from her anywhere in the loop.
///
/// The fix is a tombstone written into the **default zone** of her own private
/// database. Deleting the mirrored zone does not touch the default zone, so the
/// note survives exactly the operation that would otherwise be forgotten. Every
/// device reads it at launch and stands its own sync down.
///
/// Nothing here contains health data. The tombstone records one timestamp: when
/// she asked for the copy to be gone.
@MainActor
enum CloudDeletionTombstone {

    private static let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "clouddelete")

    static let recordType = "CaelynCloudDeletion"
    static let recordName = "cloudCopyDeletion"
    static let deletedAtField = "deletedAt"

    /// When *this device's* user last deliberately switched sync on.
    ///
    /// The comparison that makes this safe: a tombstone older than her consent on
    /// this device is a decision she has already superseded, and must not keep
    /// switching her sync off forever.
    static let syncConsentKey = "caelyn.syncConsentAt"

    static var localConsent: Date? {
        UserDefaults.standard.object(forKey: syncConsentKey) as? Date
    }

    /// Record that she chose to sync on this device, now.
    static func recordSyncConsent(at date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: syncConsentKey)
    }

    static func clearSyncConsent() {
        UserDefaults.standard.removeObject(forKey: syncConsentKey)
    }

    // MARK: - The decision

    enum Verdict: Equatable {
        /// Nothing to honour — no tombstone, or she has since asked for sync again.
        case noAction
        /// Somebody deleted the cloud copy after this device last opted in. Stand
        /// sync down here and remove any copy this device has recreated.
        case honourDeletion
    }

    /// Pure, so the rule can be tested without CloudKit, a network, or a second
    /// device.
    ///
    /// A tombstone with no local consent still counts: a device that has never
    /// recorded consent is either brand new or predates this mechanism, and in both
    /// cases the safe reading of "she deleted the cloud copy" is to honour it.
    static func verdict(tombstone: Date?, localConsent: Date?) -> Verdict {
        guard let tombstone else { return .noAction }
        guard let localConsent else { return .honourDeletion }
        // Strictly newer: consent at the same instant means she re-enabled sync as
        // part of the same decision, and fighting her would delete the copy she
        // just asked for.
        return tombstone > localConsent ? .honourDeletion : .noAction
    }

    // MARK: - CloudKit

    private static var database: CKDatabase {
        CKContainer(identifier: Persistence.cloudKitContainerID).privateCloudDatabase
    }

    private static var recordID: CKRecord.ID {
        CKRecord.ID(recordName: recordName)   // default zone, deliberately
    }

    /// Leave the note. Called immediately after the mirrored zone is removed.
    ///
    /// A failure here is logged and swallowed: the local deletion still happened
    /// and telling her it did is honest. The cost is that another device may
    /// re-upload, which is exactly the situation that existed before this type.
    static func write(deletedAt: Date = Date()) async {
        do {
            let record = CKRecord(recordType: recordType, recordID: recordID)
            record[deletedAtField] = deletedAt as CKRecordValue
            _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            log.info("Cloud delete: tombstone written so other devices stand down.")
        } catch {
            log.error("Cloud delete: could not write tombstone: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Read the note, if there is one. Nil covers both "no tombstone" and "could
    /// not ask" — and `verdict` treats nil as no action, so an offline launch never
    /// switches her sync off on a guess.
    static func fetch() async -> Date? {
        do {
            let record = try await database.record(for: recordID)
            return record[deletedAtField] as? Date
        } catch {
            return nil
        }
    }

    /// Remove the note, because she has decided she wants a cloud copy again.
    static func clear() async {
        do {
            _ = try await database.modifyRecords(saving: [], deleting: [recordID])
            log.info("Cloud delete: tombstone cleared; syncing again is allowed.")
        } catch {
            // Nothing to delete is the common case and not worth reporting.
        }
    }
}
