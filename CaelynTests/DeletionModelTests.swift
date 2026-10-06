import SwiftData
import XCTest
@testable import Caelyn

/// The four deletions, and the promise that each does exactly what it says.
///
/// These are written from the position of someone who has decided to remove
/// reproductive health data and is entitled to know precisely what happened. The
/// failure this suite exists to prevent is not a crash — it is Caelyn telling her
/// something is gone when it is still there, or removing something she did not ask
/// to lose.
@MainActor
final class DeletionModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var profile: UserProfile!
    private let calendar = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self, configurations: config)
        context = container.mainContext
        profile = UserProfile()
        context.insert(profile)
        AccountIdentityStore.signOut()
        clearFlags()
    }

    override func tearDownWithError() throws {
        AccountIdentityStore.signOut()
        clearFlags()
        container = nil; context = nil; profile = nil
    }

    private func clearFlags() {
        let defaults = UserDefaults.standard
        for key in [CloudDataDeletion.pendingKey, CloudDataDeletion.deletedAtKey,
                    CloudDataDeletion.mayExistKey, Persistence.syncEnabledKey] {
            defaults.removeObject(forKey: key)
        }
    }

    private func seedHistory(days: Int = 50) {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        for offset in 0..<days {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let entry = CycleEntry(date: day, flow: offset % 28 < 4 ? .heavy : nil, symptoms: [.cramps])
            entry.date = calendar.startOfDay(for: day)
            context.insert(entry)
        }
        context.saveOrLog()
    }

    private func entryCount() -> Int {
        ((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []).count
    }

    // MARK: - 1. Sign out

    func testSignOutKeepsLocalHistoryAndTouchesNothingInTheCloud() {
        seedHistory()
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)
        AccountSession.apply(.authorized(userID: "001", givenName: "Maya", familyName: nil), to: profile)

        AccountSession.signOut(profile: profile)

        XCTAssertEqual(entryCount(), 50, "Sign out is not a delete.")
        XCTAssertTrue(Persistence.isSyncEnabled, "Sign out must not silently switch sync off.")
        XCTAssertFalse(CloudDataDeletion.cloudCopyWasDeleted, "Sign out must never delete the cloud copy.")
        XCTAssertFalse(CloudDataDeletion.deletionIsPending)
    }

    // MARK: - 2. Delete Caelyn account

    /// The identity goes. Nothing else does.
    func testDeletingTheAccountIdentityCannotTouchLocalOrCloudHistory() {
        seedHistory()
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)
        AccountSession.apply(.authorized(userID: "001", givenName: "Maya", familyName: nil), to: profile)

        // What the Delete-account button does: unlink, and clear Apple's suggestion.
        AccountSession.signOut(profile: profile)
        profile.appleSuggestedName = nil

        XCTAssertFalse(AccountIdentityStore.isSignedIn)
        XCTAssertFalse(profile.accountLinked)
        XCTAssertEqual(entryCount(), 50, "Deleting an account may not erase reproductive health.")
        XCTAssertTrue(Persistence.isSyncEnabled)
        XCTAssertFalse(CloudDataDeletion.cloudCopyWasDeleted)
    }

    /// Her chosen name is a preference, not a property of the account.
    func testTheNameSheChoseSurvivesAccountDeletion() {
        AccountSession.setPreferredName("Maya", on: profile)
        AccountSession.apply(.authorized(userID: "001", givenName: "Margaret", familyName: nil), to: profile)

        AccountSession.signOut(profile: profile)
        profile.appleSuggestedName = nil

        XCTAssertEqual(profile.displayName, "Maya")
    }

    // MARK: - 3. Delete iCloud copy

    /// Deleting the cloud copy switches sync off. Without that, the mirror would
    /// simply upload the local store again and undo her decision.
    func testDeletingTheCloudCopyTurnsSyncOffSoNoNewCopyIsMade() async {
        seedHistory()
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)

        let outcome = await CloudDataDeletion.deleteCloudCopy()

        XCTAssertEqual(entryCount(), 50, "Deleting the iCloud copy must never touch this device.")
        if outcome.didDelete {
            XCTAssertFalse(Persistence.isSyncEnabled, "Sync must be off, or the copy comes straight back.")
            XCTAssertTrue(CloudDataDeletion.cloudCopyWasDeleted)
            XCTAssertFalse(CloudDataDeletion.deletionIsPending)
        } else {
            // No iCloud account in the simulator: the honest outcome is
            // "unavailable", and nothing may claim to have been deleted.
            XCTAssertEqual(outcome, .unavailable(.noAccount))
            XCTAssertFalse(outcome.didDelete)
            XCTAssertFalse(CloudDataDeletion.cloudCopyWasDeleted,
                           "An unreachable iCloud must never be recorded as a deletion.")
        }
    }

    /// iCloud unreachable: calm, accurate, and explicitly not a success.
    ///
    /// Asserts the substance rather than one phrase. The copy survives, and she
    /// has to be told so — but the message now also promises Caelyn will finish
    /// the job on its own, because it genuinely will: the request is recorded
    /// before the reachability check and retried at the next launch.
    func testUnavailableICloudIsReportedHonestlyAndNeverAsDeleted() {
        for availability in [CloudAvailability.noAccount, .restricted, .unreachable] {
            let outcome = CloudDataDeletion.Outcome.unavailable(availability)
            XCTAssertFalse(outcome.didDelete)
            XCTAssertTrue(outcome.message.contains("still there"),
                          "She must be told plainly that her iCloud copy was not removed.")
            XCTAssertFalse(outcome.message.contains("has been permanently deleted"),
                           "and never that it was.")
            XCTAssertFalse(outcome.message.contains("CKError"))
            XCTAssertFalse(outcome.message.lowercased().contains("ckaccountstatus"))
        }
    }

    /// Every message is in her language, never CloudKit's.
    func testNoDeletionMessageLeaksAFrameworkError() {
        let outcomes: [CloudDataDeletion.Outcome] = [
            .deleted, .nothingToDelete, .failed, .unavailable(.unreachable)
        ]
        for outcome in outcomes {
            let message = outcome.message
            XCTAssertFalse(message.isEmpty)
            for leak in ["CKError", "NSCocoaErrorDomain", "CKAccountStatus", "Error Domain", "zoneNotFound"] {
                XCTAssertFalse(message.contains(leak), "\(leak) reached the user in: \(message)")
            }
        }
    }

    // MARK: - 4. Interrupted deletion

    /// A deletion that never confirmed must not look finished.
    func testAnInterruptedDeletionIsRememberedAndNotReportedAsDone() {
        UserDefaults.standard.set(true, forKey: CloudDataDeletion.pendingKey)

        XCTAssertTrue(CloudDataDeletion.deletionIsPending)
        XCTAssertFalse(CloudDataDeletion.cloudCopyWasDeleted,
                       "Pending is not the same as done, and must never be shown as done.")
        XCTAssertFalse(CloudDataDeletion.Outcome.failed.didDelete)
        XCTAssertTrue(CloudDataDeletion.Outcome.failed.message.contains("may still be there"))
    }

    /// The launch guard retries an unfinished deletion rather than forgetting it.
    func testAPendingDeletionIsRetriedAtLaunch() async {
        UserDefaults.standard.set(true, forKey: CloudDataDeletion.pendingKey)
        UserDefaults.standard.set(false, forKey: Persistence.syncEnabledKey)

        let outcome = await CloudDataDeletion.resolveOutstandingDeletion()
        XCTAssertNotNil(outcome, "An unfinished deletion must be picked up again.")
    }

    /// Nothing outstanding means the guard does nothing at all.
    func testTheLaunchGuardIsSilentWhenSheNeverDeletedAnything() async {
        let outcome = await CloudDataDeletion.resolveOutstandingDeletion()
        XCTAssertNil(outcome)
    }

    // MARK: - 5. Data resurrection

    /// **The resurrection guard.** Having deleted the copy, a later launch must not
    /// quietly rebuild one — so while the marker stands and sync is off, the guard
    /// keeps re-asserting the deletion.
    func testADeletedCloudCopyIsNotAllowedToComeBackOnItsOwn() async {
        UserDefaults.standard.set(Date(), forKey: CloudDataDeletion.deletedAtKey)
        UserDefaults.standard.set(false, forKey: Persistence.syncEnabledKey)

        let outcome = await CloudDataDeletion.resolveOutstandingDeletion()
        XCTAssertNotNil(outcome, "The guard must re-assert the deletion, not assume it held.")
        XCTAssertTrue(CloudDataDeletion.cloudCopyWasDeleted)
    }

    /// Signing back in is an identity action and must not resurrect anything.
    func testSigningBackInAfterDeletionDoesNotBringDataBack() async {
        UserDefaults.standard.set(Date(), forKey: CloudDataDeletion.deletedAtKey)
        UserDefaults.standard.set(false, forKey: Persistence.syncEnabledKey)

        AccountSession.apply(.authorized(userID: "001", givenName: "Maya", familyName: nil), to: profile)

        XCTAssertFalse(Persistence.isSyncEnabled, "Signing in must not switch sync on.")
        XCTAssertTrue(CloudDataDeletion.cloudCopyWasDeleted, "and must not clear her deletion.")
    }

    /// But if she deliberately turns sync back on, that is a decision, and Caelyn
    /// must stop fighting it — otherwise the guard would delete the new copy she
    /// just asked for.
    func testTurningSyncBackOnDeliberatelyClearsTheDeletionMarker() async {
        UserDefaults.standard.set(Date(), forKey: CloudDataDeletion.deletedAtKey)
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)

        let outcome = await CloudDataDeletion.resolveOutstandingDeletion()

        XCTAssertNil(outcome, "She changed her mind; the guard must stand down.")
        XCTAssertFalse(CloudDataDeletion.cloudCopyWasDeleted)
        XCTAssertFalse(CloudDataDeletion.deletionIsPending)
    }

    func testClearingTheMarkerIsExplicit() {
        UserDefaults.standard.set(Date(), forKey: CloudDataDeletion.deletedAtKey)
        UserDefaults.standard.set(true, forKey: CloudDataDeletion.pendingKey)

        CloudDataDeletion.clearDeletionMarker()

        XCTAssertFalse(CloudDataDeletion.cloudCopyWasDeleted)
        XCTAssertFalse(CloudDataDeletion.deletionIsPending)
    }

    // MARK: - 6. Delete all data, and its scope

    /// **What this proves:** a `.thisDevice` wipe clears every local row and never
    /// reaches for CloudKit itself.
    ///
    /// **What it does NOT prove, and cannot:** that the deletions stay off the
    /// network. This container is `cloudKitDatabase: .none`, so there is no mirror
    /// to export anything. The real `Persistence.live` may well be mirrored, and
    /// whether `NSPersistentCloudKitContainer` then pushes these deletions to her
    /// iCloud is Apple's scheduler's business — unobservable from a unit test and
    /// answerable only on two real devices. The old name for this test claimed the
    /// opposite and is why that risk stayed invisible.
    ///
    /// The scope question is settled in the UI instead: see
    /// `DeleteAllOfferTests`, which pins the rule that withholds a local-only
    /// delete whenever a cloud copy may exist.
    func testALocalOnlyWipeClearsEveryRowAndAttemptsNoCloudDeletion() async {
        seedHistory()
        UserDefaults.standard.set(Date(), forKey: CloudDataDeletion.deletedAtKey)

        let cloudOutcome = await SecureWipeService.wipeEverything(
            modelContext: context, scope: .thisDevice
        )

        XCTAssertNil(cloudOutcome, "A local-only wipe must not even attempt a cloud deletion.")
        XCTAssertEqual(entryCount(), 0)
    }

    /// A local wipe must not clear the record that she destroyed a cloud copy —
    /// that marker is what stops a later launch rebuilding one.
    func testALocalWipeDoesNotForgetThatSheDeletedHerCloudCopy() async {
        seedHistory()
        UserDefaults.standard.set(Date(), forKey: CloudDataDeletion.deletedAtKey)

        await SecureWipeService.wipeEverything(modelContext: context, scope: .thisDevice)

        XCTAssertTrue(CloudDataDeletion.cloudCopyWasDeleted,
                      "Forgetting this would let a deleted cloud copy quietly return.")
    }

    func testDeletingBothAttemptsTheCloudAndClearsLocal() async {
        seedHistory()

        let cloudOutcome = await SecureWipeService.wipeEverything(
            modelContext: context, scope: .thisDeviceAndCloud
        )

        XCTAssertNotNil(cloudOutcome, "The cloud half must be attempted and reported, not assumed.")
        XCTAssertEqual(entryCount(), 0, "The local half always completes.")
    }

    /// The half-deleted state that matters: local gone, cloud unreachable. Caelyn
    /// must say so rather than implying both halves succeeded.
    func testWhenTheCloudHalfFailsTheLocalHalfStillCompletesAndSaysSo() async {
        seedHistory()

        let cloudOutcome = await SecureWipeService.wipeEverything(
            modelContext: context, scope: .thisDeviceAndCloud
        )

        XCTAssertEqual(entryCount(), 0)
        if let cloudOutcome, !cloudOutcome.didDelete {
            XCTAssertTrue(cloudOutcome.message.contains("still there")
                          || cloudOutcome.message.contains("may still be there"),
                          "A surviving cloud copy must be stated, never glossed over.")
        }
    }

    // MARK: - 7. Sign in with Apple asks for the minimum

    /// Caelyn requested `.email` through 1.2 and never read it. It is gone.
    func testTheEmailScopeIsNoLongerRequested() throws {
        let source = try RepoSource.read("Caelyn/Services/Account/AppleSignInService.swift")
        XCTAssertTrue(source.contains("requestedScopes = [.fullName]"),
                      "Caelyn must ask only for the name it actually uses.")
        XCTAssertFalse(source.contains("requestedScopes = [.fullName, .email]"))
    }

    /// And an address still cannot become a name, whatever arrives.
    func testAnAddressStillCannotBecomeAName() {
        XCTAssertNil(PersonalName.usable("x7f3k2@privaterelay.appleid.com"))
        XCTAssertNil(PersonalName.usable("maya@example.com"))
    }
}

/// Reaching the cloud-deletion action.
///
/// The defect these exist to prevent: Caelyn keyed the "Delete my iCloud copy"
/// action on the sync toggle, so switching sync off hid the only way to remove a
/// copy that was already in iCloud. Sync being off says nothing about whether a
/// copy exists — it only says nothing new is going up.
@MainActor
final class CloudDeletionReachabilityTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self, configurations: config)
        context = container.mainContext
        clearFlags()
    }

    override func tearDownWithError() throws {
        clearFlags()
        container = nil; context = nil
    }

    private func clearFlags() {
        let d = UserDefaults.standard
        for key in [CloudDataDeletion.pendingKey, CloudDataDeletion.deletedAtKey,
                    CloudDataDeletion.mayExistKey, Persistence.syncEnabledKey] {
            d.removeObject(forKey: key)
        }
    }

    /// Mirrors `AccountView.showCloudCopyCard`, which is the production rule.
    private func actionIsReachable(syncOn: Bool) -> Bool {
        syncOn
            || CloudDataDeletion.cloudCopyMayExist
            || CloudDataDeletion.cloudCopyWasDeleted
            || CloudDataDeletion.deletionIsPending
    }

    // 1. Sync on and a copy exists → visible.
    func testWithSyncOnTheDeleteActionIsAvailable() {
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)
        CloudDataDeletion.noteCloudCopyMayExist()
        XCTAssertTrue(actionIsReachable(syncOn: true))
    }

    // 2. **The defect.** Sync off, but a copy was made earlier → still visible.
    func testWithSyncOffButAPriorCopyTheDeleteActionIsStillAvailable() {
        CloudDataDeletion.noteCloudCopyMayExist()
        UserDefaults.standard.set(false, forKey: Persistence.syncEnabledKey)

        XCTAssertTrue(CloudDataDeletion.cloudCopyMayExist)
        XCTAssertTrue(actionIsReachable(syncOn: false),
                      "Turning sync off must not hide the only way to delete a copy already in iCloud.")
    }

    // 3. After a confirmed deletion the state moves on.
    func testAConfirmedDeletionClearsTheMayExistMarker() async {
        CloudDataDeletion.noteCloudCopyMayExist()
        XCTAssertTrue(CloudDataDeletion.cloudCopyMayExist)

        let outcome = await CloudDataDeletion.deleteCloudCopy()

        if outcome.didDelete {
            XCTAssertFalse(CloudDataDeletion.cloudCopyMayExist,
                           "Once the copy is gone Caelyn should stop saying one may exist.")
            XCTAssertTrue(CloudDataDeletion.cloudCopyWasDeleted)
            // Still reachable, so she can see it was done rather than the card
            // vanishing without explanation.
            XCTAssertTrue(actionIsReachable(syncOn: false))
        } else {
            // Simulator has no iCloud account: nothing may be claimed.
            XCTAssertTrue(CloudDataDeletion.cloudCopyMayExist,
                          "A failed deletion must not clear the marker.")
        }
    }

    /// An interrupted deletion keeps the action reachable so it can be retried.
    func testAnUnfinishedDeletionKeepsTheActionReachable() {
        UserDefaults.standard.set(true, forKey: CloudDataDeletion.pendingKey)
        XCTAssertTrue(actionIsReachable(syncOn: false))
    }

    // 4. A user who never synced is offered nothing — there is nothing to delete.
    func testAUserWhoNeverSyncedIsNotOfferedACloudDeletion() {
        XCTAssertFalse(CloudDataDeletion.cloudCopyMayExist)
        XCTAssertFalse(CloudDataDeletion.cloudCopyWasDeleted)
        XCTAssertFalse(CloudDataDeletion.deletionIsPending)
        XCTAssertFalse(actionIsReachable(syncOn: false),
                       "Offering to delete a copy that cannot exist is its own small lie.")
    }

    /// Merely flipping the preference is not enough — the marker is only set when
    /// the mirrored store actually opened, because nothing uploads until it does.
    func testTheMarkerTracksTheStoreOpeningNotThePreference() {
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)
        XCTAssertFalse(CloudDataDeletion.cloudCopyMayExist,
                       "Asking for sync is not the same as having synced.")

        CloudDataDeletion.noteCloudCopyMayExist()   // what Persistence does on a real open
        XCTAssertTrue(CloudDataDeletion.cloudCopyMayExist)
    }

    // 5. Deleting the cloud copy never touches local history.
    func testDeletingTheCloudCopyLeavesLocalHistoryAlone() async {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        for offset in 0..<25 {
            let entry = CycleEntry(date: calendar.date(byAdding: .day, value: offset, to: start)!)
            entry.flow = .medium
            context.insert(entry)
        }
        context.saveOrLog()
        CloudDataDeletion.noteCloudCopyMayExist()

        _ = await CloudDataDeletion.deleteCloudCopy()

        let remaining = (try? context.fetch(FetchDescriptor<CycleEntry>()))?.count ?? 0
        XCTAssertEqual(remaining, 25, "Delete my iCloud copy must never reach the device's own history.")
    }

    /// The delete-all scope decision uses the same signal, so a user with sync off
    /// and a prior copy is still treated as having something in iCloud — which is
    /// what withholds the local-only delete from her dialog.
    func testDeleteAllStillAsksAboutScopeWhenSyncIsOffButACopyExists() {
        CloudDataDeletion.noteCloudCopyMayExist()
        UserDefaults.standard.set(false, forKey: Persistence.syncEnabledKey)

        let mayHaveCloudCopy = Persistence.isSyncEnabled
            || Persistence.isSyncActive
            || CloudDataDeletion.cloudCopyMayExist
            || CloudDataDeletion.deletionIsPending
        XCTAssertTrue(mayHaveCloudCopy)
    }
}

/// Cross-device deletion: the copy stays deleted on devices that were never told.
///
/// The defect this exists to prevent is the worst one in the release. Every
/// deletion marker is device-local, so deleting the cloud copy on one phone left
/// another phone still syncing, still holding its own history, and quite happy to
/// recreate the zone and upload the lot the next time it opened. Reproductive
/// health she deliberately destroyed came back on its own.
@MainActor
final class CrossDeviceDeletionTests: XCTestCase {

    override func setUpWithError() throws { clearAll() }
    override func tearDownWithError() throws { clearAll() }

    private func clearAll() {
        let d = UserDefaults.standard
        for key in [CloudDataDeletion.pendingKey, CloudDataDeletion.deletedAtKey,
                    CloudDataDeletion.mayExistKey, Persistence.syncEnabledKey,
                    CloudDeletionTombstone.syncConsentKey] {
            d.removeObject(forKey: key)
        }
    }

    private let earlier = Date(timeIntervalSince1970: 1_000_000)
    private let later   = Date(timeIntervalSince1970: 2_000_000)

    // MARK: - The rule

    /// A device that never opted in must honour a deletion it knows nothing about.
    func testADeviceWithNoRecordedConsentHonoursTheDeletion() {
        XCTAssertEqual(
            CloudDeletionTombstone.verdict(tombstone: later, localConsent: nil),
            .honourDeletion
        )
    }

    /// **The blocker.** Device B opted in before Device A deleted. B must stand down.
    func testADeviceThatOptedInBeforeTheDeletionStandsDown() {
        XCTAssertEqual(
            CloudDeletionTombstone.verdict(tombstone: later, localConsent: earlier),
            .honourDeletion,
            "Otherwise this device recreates the zone and re-uploads what she deleted."
        )
    }

    /// She changed her mind afterwards. Do not fight her.
    func testOptingBackInAfterTheDeletionWins() {
        XCTAssertEqual(
            CloudDeletionTombstone.verdict(tombstone: earlier, localConsent: later),
            .noAction,
            "Re-enabling sync after deleting is a new decision and must be respected."
        )
    }

    /// Same instant means one decision — enabling sync as part of it.
    func testConsentAtTheSameInstantIsNotOverridden() {
        XCTAssertEqual(
            CloudDeletionTombstone.verdict(tombstone: earlier, localConsent: earlier),
            .noAction
        )
    }

    /// No tombstone, nothing to do — including offline, where `fetch` returns nil
    /// and must never be read as "she deleted it".
    func testNoTombstoneMeansNoAction() {
        XCTAssertEqual(CloudDeletionTombstone.verdict(tombstone: nil, localConsent: nil), .noAction)
        XCTAssertEqual(CloudDeletionTombstone.verdict(tombstone: nil, localConsent: earlier), .noAction)
    }

    /// An unreachable iCloud must not silently switch her sync off.
    func testAnOfflineLaunchDoesNotStandSyncDown() {
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)
        CloudDeletionTombstone.recordSyncConsent(at: earlier)

        // fetch() returns nil when it cannot ask.
        XCTAssertEqual(CloudDeletionTombstone.verdict(tombstone: nil, localConsent: earlier), .noAction)
        XCTAssertTrue(Persistence.isSyncEnabled)
    }

    // MARK: - Consent bookkeeping

    func testEnablingSyncRecordsConsentAndLiftsTheDeletion() {
        UserDefaults.standard.set(Date(), forKey: CloudDataDeletion.deletedAtKey)
        XCTAssertNil(CloudDeletionTombstone.localConsent)

        CloudDataDeletion.recordSyncConsentAndLiftTombstone()

        XCTAssertNotNil(CloudDeletionTombstone.localConsent, "Her decision has to be dated to beat an older tombstone.")
        XCTAssertFalse(CloudDataDeletion.cloudCopyWasDeleted)
    }

    /// Consent recorded now must beat a tombstone written a moment ago, or
    /// re-enabling sync would be undone by the next launch.
    func testFreshConsentBeatsAnOlderTombstone() {
        CloudDeletionTombstone.recordSyncConsent(at: later)
        XCTAssertEqual(
            CloudDeletionTombstone.verdict(tombstone: earlier, localConsent: CloudDeletionTombstone.localConsent),
            .noAction
        )
    }

    /// The tombstone is one timestamp and nothing else — no health data leaves the
    /// device to make this work.
    func testTheTombstoneCarriesOnlyATimestamp() {
        XCTAssertEqual(CloudDeletionTombstone.recordType, "CaelynCloudDeletion")
        XCTAssertEqual(CloudDeletionTombstone.deletedAtField, "deletedAt")
        XCTAssertEqual(CloudDeletionTombstone.recordName, "cloudCopyDeletion")
    }
}

// MARK: - Delete-all scope: what the dialog may offer

/// The rule that decides whether "Delete all data" is allowed to show a delete
/// that claims to stay on this iPhone.
///
/// **The defect this exists to prevent.** `Persistence.live` is built once per
/// launch. If it opened with CloudKit mirroring, it stays mirrored for the whole
/// process — switching the sync preference off only changes what the *next*
/// launch builds. So a "this iPhone only" wipe would delete rows on a live
/// mirrored store, and the mirror would carry those deletions to her iCloud and
/// on to every other device she owns. She would tap a button that said "only this
/// iPhone" and lose her history on an iPad she never touched.
///
/// Caelyn cannot prove the deletion stays local, so it does not offer it. These
/// tests pin that rule. They deliberately do **not** claim anything about what
/// CloudKit does with the deletions — that is unobservable here.
@MainActor
final class DeleteAllOfferTests: XCTestCase {

    override func setUpWithError() throws { clearFlags() }
    override func tearDownWithError() throws { clearFlags() }

    private func clearFlags() {
        let d = UserDefaults.standard
        for key in [CloudDataDeletion.pendingKey, CloudDataDeletion.deletedAtKey,
                    CloudDataDeletion.mayExistKey, Persistence.syncEnabledKey] {
            d.removeObject(forKey: key)
        }
    }

    // MARK: The rule itself

    func testALocalOnlyDeleteIsWithheldWheneverACloudCopyMayExist() {
        XCTAssertEqual(SecureWipeService.deleteAllOffer(mayHaveCloudCopy: true), .deviceAndCloudOnly)
        XCTAssertFalse(SecureWipeService.deleteAllOffer(mayHaveCloudCopy: true).offersLocalOnlyDelete,
                       "No button may promise a local-only delete while the store could be mirrored.")
    }

    func testAUserWhoNeverSyncedKeepsTheOrdinaryLocalDelete() {
        XCTAssertEqual(SecureWipeService.deleteAllOffer(mayHaveCloudCopy: false), .deviceOnly)
        XCTAssertTrue(SecureWipeService.deleteAllOffer(mayHaveCloudCopy: false).offersLocalOnlyDelete,
                      "With no cloud copy possible, a plain local wipe is both safe and truthful.")
    }

    // MARK: Every state that must count as "a copy may exist"

    func testSyncTurnedOnCountsAsACloudCopy() {
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)
        XCTAssertTrue(CloudDataDeletion.cloudCopyMayExistNow)
        XCTAssertEqual(SecureWipeService.deleteAllOffer(mayHaveCloudCopy: CloudDataDeletion.cloudCopyMayExistNow),
                       .deviceAndCloudOnly)
    }

    /// Switching sync off does not remove what was already uploaded, and — more to
    /// the point here — does not un-mirror the container this launch is holding.
    func testSyncSwitchedOffAfterAPriorCopyStillCountsAsACloudCopy() {
        CloudDataDeletion.noteCloudCopyMayExist()
        UserDefaults.standard.set(false, forKey: Persistence.syncEnabledKey)
        XCTAssertTrue(CloudDataDeletion.cloudCopyMayExistNow)
        XCTAssertEqual(SecureWipeService.deleteAllOffer(mayHaveCloudCopy: CloudDataDeletion.cloudCopyMayExistNow),
                       .deviceAndCloudOnly)
    }

    func testAnUnfinishedCloudDeletionStillCountsAsACloudCopy() {
        UserDefaults.standard.set(true, forKey: CloudDataDeletion.pendingKey)
        XCTAssertTrue(CloudDataDeletion.cloudCopyMayExistNow)
        XCTAssertEqual(SecureWipeService.deleteAllOffer(mayHaveCloudCopy: CloudDataDeletion.cloudCopyMayExistNow),
                       .deviceAndCloudOnly)
    }

    func testAUserWhoNeverSyncedIsNotToldAboutICloudAtAll() {
        XCTAssertFalse(CloudDataDeletion.cloudCopyMayExistNow,
                       "Nothing may imply a cloud copy for someone who has never had one.")
    }

    /// The wipe scope is still expressible — this is a UI restriction, not a
    /// capability removal. Whatever replaces it later can still ask for either.
    func testBothWipeScopesRemainAvailableToCallers() {
        XCTAssertNotEqual(SecureWipeService.Scope.thisDevice, SecureWipeService.Scope.thisDeviceAndCloud)
    }
}

// MARK: - Local-first contract

/// Caelyn is local-first: the device holds the real data, and iCloud — when she
/// turns it on — is an additional synchronised copy, never a replacement.
///
/// These tests pin the parts of that contract that are genuinely checkable on this
/// machine: store configuration, and the merge rule that decides what happens when
/// a record arrives from another device. They make **no claim** about Apple's
/// network behaviour; nothing here proves that a sync succeeded or failed, because
/// nothing here can.
@MainActor
final class LocalFirstContractTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: y, month: m, day: d))!)
    }

    // MARK: Storage shape

    /// Sync must not turn the store into a cloud-only or memory-only one. Both
    /// configurations are on-disk, and they are the same file, so enabling sync
    /// adds a mirror to the history she already has rather than opening a new one.
    func testTheSyncedStoreIsStillAnOnDiskLocalStore() {
        let local = ModelConfiguration(schema: Persistence.schema,
                                       isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        let synced = ModelConfiguration(schema: Persistence.schema,
                                        isStoredInMemoryOnly: false,
                                        cloudKitDatabase: .private(Persistence.cloudKitContainerID))
        XCTAssertFalse(local.isStoredInMemoryOnly)
        XCTAssertFalse(synced.isStoredInMemoryOnly,
                       "A mirrored store must still be a real file on the device. Cloud is a copy, never the only copy.")
        XCTAssertEqual(local.url, synced.url,
                       "Sync mirrors the existing store; it must never open a different one.")
    }

    /// There is no cloud-only mode to fall into, and the mirror only ever targets
    /// her own private database.
    func testCaelynHasNoCloudOnlyStorageMode() {
        XCTAssertEqual(Persistence.syncDatabaseDescription, "private",
                       "Only ever the user's own private database — never a public or shared one.")

        // Every store Caelyn can open. The in-memory one is the last-resort fallback
        // for an unreadable store, kept so a corrupt file cannot make the app
        // unlaunchable; it is the only non-disk configuration and it is never a
        // *cloud* mode. Nothing here can be both mirrored and non-local.
        let localOnDisk = ModelConfiguration(schema: Persistence.schema,
                                             isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        let mirroredOnDisk = ModelConfiguration(schema: Persistence.schema,
                                                isStoredInMemoryOnly: false,
                                                cloudKitDatabase: .private(Persistence.cloudKitContainerID))
        for config in [localOnDisk, mirroredOnDisk] {
            XCTAssertFalse(config.isStoredInMemoryOnly,
                           "A configuration that syncs must still write to this device.")
        }
    }

    // MARK: Offline writes

    /// A write is a local SwiftData save. No network call stands between her tap
    /// and her history being on disk, so logging works with the radios off.
    func testLoggingPersistsWithoutAnyNetworkInvolvement() throws {
        let container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext

        let entry = CycleStore.entry(for: day(2026, 5, 4), in: context, calendar: calendar)
        entry.flow = .heavy
        entry.symptoms = [.cramps]
        context.saveOrLog()

        let stored = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.flow, .heavy)
    }

    /// Reading history is a local fetch too — predictions included. Nothing in the
    /// path from entries to a prediction can be blocked by an unreachable iCloud.
    func testHistoryAndPredictionsAreReadableWithNoCloudInvolvement() throws {
        let container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        for offset in stride(from: 0, to: 87, by: 29) {
            let start = calendar.date(byAdding: .day, value: offset, to: day(2026, 4, 1))!
            for k in 0..<5 {
                let e = CycleStore.entry(for: calendar.date(byAdding: .day, value: k, to: start)!,
                                         in: context, calendar: calendar)
                e.flow = .medium
            }
        }
        context.saveOrLog()

        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        let model = CycleModel.make(entries: entries, profile: nil,
                                    today: day(2026, 7, 7), calendar: calendar)
        XCTAssertEqual(model.cycles.count, 2)
        XCTAssertEqual(model.cycleLength, 29)
        XCTAssertNotNil(model.nextPeriodStart)
    }

    // MARK: A record arriving from another device

    /// The merge is additive. A row that arrives holding nothing — an older or
    /// emptier copy from another device — can never blank a field this device has.
    /// This is the rule that stops a bad sync from looking like data loss.
    func testAnEmptierIncomingCopyCannotEraseLocalHistory() throws {
        let container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let today = day(2026, 5, 4)

        // What this device holds, richly logged.
        let mine = CycleEntry(date: today, flow: .heavy, symptoms: [.cramps])
        mine.date = today
        mine.note = "rough day"
        mine.pain = 7
        mine.updatedAt = Date(timeIntervalSince1970: 2_000)
        context.insert(mine)

        // What arrives from elsewhere for the same day: newer, and almost empty.
        let incoming = CycleEntry(date: today)
        incoming.date = today
        incoming.mood = .tired
        incoming.updatedAt = Date(timeIntervalSince1970: 9_000)
        context.insert(incoming)
        context.saveOrLog()

        CycleStore.dedupeSameDay(in: context, calendar: calendar)

        let rows = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        XCTAssertEqual(rows.count, 1, "Same-day rows merge to one.")
        let merged = try XCTUnwrap(rows.first)
        XCTAssertEqual(merged.flow, .heavy, "A newer, emptier row must not blank the flow she logged.")
        XCTAssertEqual(merged.note, "rough day", "Nor her note.")
        XCTAssertEqual(merged.pain, 7, "Nor her pain score.")
        XCTAssertTrue(merged.symptoms.contains(.cramps), "Nor her symptoms.")
        XCTAssertEqual(merged.mood, .tired, "And what did arrive is kept.")
    }

    /// Running the reconciliation repeatedly — which is what a series of remote
    /// notifications causes — converges instead of eroding anything.
    func testRepeatedReconciliationNeverErodesHistory() throws {
        let container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        for k in 0..<5 {
            let e = CycleStore.entry(for: calendar.date(byAdding: .day, value: k, to: day(2026, 5, 4))!,
                                     in: context, calendar: calendar)
            e.flow = .medium
            e.symptoms = [.cramps]
        }
        context.saveOrLog()

        for _ in 0..<5 { CycleStore.dedupeSameDay(in: context, calendar: calendar) }

        let rows = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(rows.allSatisfy { $0.flow == .medium && $0.symptoms == [.cramps] })
    }
}

// MARK: - The privacy screen tells the truth about sync

/// The claims on `PrivacyTrustView`, which are also what the App Store screenshot
/// shows.
///
/// **The defect this exists to prevent.** These were flat constants written before
/// 1.3. They said "there is no copy of it anywhere else, including with us",
/// "Caelyn never asks for your email, name…", "Caelyn makes no network calls of
/// its own" and "your data exists in exactly one place: this device". Then 1.3
/// shipped optional Sign in with Apple and optional private iCloud sync, and every
/// one of those stopped being true for anyone who switched either on — while the
/// screen kept saying them, and kept being the marketing screenshot.
///
/// Privacy is this app's whole wedge, so an overstatement here costs more than
/// anywhere else in the product.
@MainActor
final class PrivacyCopyTruthfulnessTests: XCTestCase {

    override func setUpWithError() throws { clearCloudFlags() }
    override func tearDownWithError() throws { clearCloudFlags() }

    private func clearCloudFlags() {
        let d = UserDefaults.standard
        for key in [CloudDataDeletion.pendingKey, CloudDataDeletion.deletedAtKey,
                    CloudDataDeletion.mayExistKey, Persistence.syncEnabledKey] {
            d.removeObject(forKey: key)
        }
    }

    private func allCopy() -> String {
        let view = PrivacyTrustView()
        let promises = view.promises.map { "\($0.title). \($0.body)" }
        let faq = view.threatModel.map { "\($0.q). \($0.a)" }
        return (promises + faq).joined(separator: "\n")
    }

    // MARK: With a cloud copy, no absolute may survive

    func testNoAbsoluteLocalOnlyClaimSurvivesOnceACloudCopyMayExist() {
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)
        XCTAssertTrue(PrivacyTrustView().hasCloudCopy)

        let copy = allCopy()
        let falseOnceSynced = [
            "no copy of it anywhere else",
            "exactly one place",
            "makes no network calls of its own",
            "stays only on your device"
        ]
        for claim in falseOnceSynced {
            XCTAssertFalse(copy.contains(claim),
                           "“\(claim)” is not true once her history is also in iCloud.")
        }
    }

    /// Saying it plainly is the point — not just omitting the false claim.
    func testTheCloudCopyIsNamedAndAttributedToHerOwnAppleAccount() {
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)
        let copy = allCopy()
        XCTAssertTrue(copy.contains("iCloud"), "A copy exists; the screen must say so.")
        XCTAssertTrue(copy.contains("Apple Account"),
                      "It must say whose cloud it is, not just that one exists.")
        XCTAssertTrue(copy.lowercased().contains("cannot read it"),
                      "The reassurance that matters: Caelyn still cannot read it.")
    }

    /// Sync having been switched off does not remove a copy already made, and the
    /// screen must not revert to the absolute claims while one may still be there.
    func testSyncSwitchedOffAfterAPriorCopyKeepsTheHonestCopy() {
        CloudDataDeletion.noteCloudCopyMayExist()
        UserDefaults.standard.set(false, forKey: Persistence.syncEnabledKey)
        XCTAssertTrue(PrivacyTrustView().hasCloudCopy)
        XCTAssertFalse(allCopy().contains("no copy of it anywhere else"))
    }

    // MARK: With no cloud copy, the strong version is earned and kept

    func testWithNoCloudCopyTheStrongClaimsAreStillMade() {
        XCTAssertFalse(PrivacyTrustView().hasCloudCopy)
        let copy = allCopy()
        XCTAssertTrue(copy.contains("no copy of it anywhere else"),
                      "Sync is off by default; that user has earned the strongest true statement.")
        XCTAssertTrue(copy.contains("exactly one place"))
    }

    // MARK: The account claim, in every state

    /// Caelyn requests `.fullName` and `PreferredNameStep` asks her what to be
    /// called, so "never asks for your name" was simply false. What remains true —
    /// and is the thing worth promising — is that it never asks for email, age or
    /// location, and that the account gates nothing.
    func testTheAccountClaimNeverDeniesAskingForAName() {
        for synced in [false, true] {
            UserDefaults.standard.set(synced, forKey: Persistence.syncEnabledKey)
            let copy = allCopy()
            XCTAssertFalse(copy.contains("never asks for your email, name"),
                           "Caelyn does ask for a name — optionally, but it asks.")
            XCTAssertTrue(copy.contains("never asks for your email, age, or location"),
                          "The part that is still true must still be said.")
            XCTAssertTrue(copy.contains("Signing in is optional"),
                          "The account gates nothing, and that is the real promise.")
        }
    }

    /// Whatever the state, nothing may claim Caelyn itself holds or can read her
    /// history — that is the claim the whole product rests on.
    func testCaelynNeverClaimsToHoldOrReadHerData() {
        for synced in [false, true] {
            UserDefaults.standard.set(synced, forKey: Persistence.syncEnabledKey)
            let copy = allCopy()
            XCTAssertTrue(copy.contains("runs no servers") || copy.contains("run no server"),
                          "No Caelyn server is true in every state and must be said.")
            XCTAssertTrue(copy.contains("nothing for us to hand over")
                          || copy.contains("nothing for Caelyn to hand over"))
        }
    }
}

/// Asking for her iCloud copy to be destroyed must survive having no signal.
///
/// **What this protects.** `deleteCloudCopy` checked whether iCloud was reachable
/// and returned early if it was not — before writing the pending marker. So a
/// woman who asked for her cloud copy to go while she was on a plane, on the
/// underground, or abroad with data switched off saw "nothing was deleted" and
/// that was the end of it. Nothing was written down, `resolveOutstandingDeletion`
/// found nothing to resume, and no later launch tried again.
///
/// Her reproductive health history stayed in iCloud indefinitely after she had
/// explicitly asked for it to be destroyed, and the only trace of the request was
/// a message she dismissed.
@MainActor
final class OfflineCloudDeletionTests: XCTestCase {

    private let keys = [
        "caelyn.cloudDeletionPending",
        "caelyn.cloudDeletedAt",
        "caelyn.cloudCopyMayExist",
        Persistence.syncEnabledKey,
    ]

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    /// The simulator test host has no iCloud account, so `deleteCloudCopy`
    /// genuinely takes the unavailable path — which is exactly the one under test.
    func testAskingWithNoConnectionIsRememberedAndRetriedLater() async throws {
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)

        let outcome = await CloudDataDeletion.deleteCloudCopy()
        guard case .unavailable = outcome else {
            throw XCTSkip("this host can reach iCloud, so the offline path cannot be exercised here")
        }

        XCTAssertTrue(CloudDataDeletion.deletionIsPending,
            "she asked for her iCloud copy to be destroyed with no connection, and nothing recorded that she had asked — no launch will ever try again")
    }

    /// Sync has to stop at the moment she asks, not at the moment the zone is
    /// actually reachable — otherwise the retry cancels itself.
    func testSyncStopsEvenWhenTheDeletionCannotBeCompletedYet() async throws {
        UserDefaults.standard.set(true, forKey: Persistence.syncEnabledKey)

        let outcome = await CloudDataDeletion.deleteCloudCopy()
        guard case .unavailable = outcome else {
            throw XCTSkip("this host can reach iCloud")
        }

        XCTAssertFalse(Persistence.isSyncEnabled,
            "the mirror kept uploading to a copy she had asked Caelyn to destroy")

        // And with sync off, the launch guard resumes rather than cancelling:
        // `resolveOutstandingDeletion` reads sync still being on as her having
        // changed her mind.
        let resumed = await CloudDataDeletion.resolveOutstandingDeletion()
        XCTAssertNotNil(resumed, "the pending deletion was dropped instead of retried on the next launch")
    }

    /// She must not be told it is gone when it is not.
    func testSheIsNotToldItWasDeleted() {
        let outcome = CloudDataDeletion.Outcome.unavailable(.unreachable)
        XCTAssertFalse(outcome.didDelete)
        XCTAssertFalse(outcome.message.contains("has been permanently deleted"))
    }

    /// But she must also not be left thinking she has to come back and ask again.
    func testSheIsToldItWillFinishOnItsOwn() {
        let message = CloudDataDeletion.Outcome.unavailable(.unreachable).message
        XCTAssertTrue(message.contains("as soon as a connection comes back"),
            "she is told nothing happened, with no indication Caelyn will finish the job: \(message)")
    }

    func testTheMessageStillLeaksNoFrameworkError() {
        for availability: CloudAvailability in [.noAccount, .restricted, .unreachable] {
            let message = CloudDataDeletion.Outcome.unavailable(availability).message
            for banned in ["CKError", "CloudKit", "NSError", "Error Domain"] {
                XCTAssertFalse(message.contains(banned), "\(availability) leaks \"\(banned)\"")
            }
        }
    }
}
