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
    func testUnavailableICloudIsReportedHonestlyAndNeverAsDeleted() {
        for availability in [CloudAvailability.noAccount, .restricted, .unreachable] {
            let outcome = CloudDataDeletion.Outcome.unavailable(availability)
            XCTAssertFalse(outcome.didDelete)
            XCTAssertTrue(outcome.message.contains("Nothing was deleted"),
                          "She must be told plainly that nothing was removed.")
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

    func testDeletingLocalOnlyRemovesEverythingHereAndNothingInTheCloud() async {
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
            XCTAssertTrue(cloudOutcome.message.contains("Nothing was deleted")
                          || cloudOutcome.message.contains("may still be there"),
                          "A surviving cloud copy must be stated, never glossed over.")
        }
    }

    // MARK: - 7. Sign in with Apple asks for the minimum

    /// Caelyn requested `.email` through 1.2 and never read it. It is gone.
    func testTheEmailScopeIsNoLongerRequested() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Caelyn/Services/Account/AppleSignInService.swift"),
            encoding: .utf8
        )
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

    /// The delete-all scope question uses the same signal, so a user with sync off
    /// and a prior copy is still asked which storage she means.
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
