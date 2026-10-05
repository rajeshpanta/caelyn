import CoreData
import XCTest
@testable import Caelyn

/// Caelyn may only say "backed up" when something has actually been backed up.
///
/// **What this protects.** The sync card claimed "Your history is backed up to
/// your private iCloud" on the strength of `CKContainer.accountStatus()` — she is
/// signed in — and `Persistence.isSyncActive` — the mirrored store opened.
/// Neither is evidence that one record was uploaded.
///
/// CloudKit keeps separate Development and Production schemas, and a field that
/// is not in Production yet fails every export of its record type. `dayKey` is
/// exactly such a field. In that state the account is fine, the store opens fine,
/// and reads and writes work fine, because the store is local either way — so
/// nothing she can see is wrong, and the screen tells her her reproductive health
/// history is safely in iCloud while it is sitting on one phone. If that phone is
/// lost, so is everything.
///
/// The same shape covers a full iCloud account, a record Apple rejects, and an
/// account that loses access mid-session.
@MainActor
final class CloudSyncHealthTests: XCTestCase {

    private var health: CloudSyncHealth { .shared }

    override func setUp() { super.setUp(); health.resetForTesting() }
    override func tearDown() { health.resetForTesting(); super.tearDown() }

    private func line(_ availability: CloudAvailability = .available) -> String {
        health.state.message(availability: availability)
    }

    // MARK: - The claim

    func testNothingIsClaimedBeforeAnExportHasSucceeded() {
        XCTAssertEqual(health.state, .waiting)
        XCTAssertFalse(line().contains("is backed up"),
            "Caelyn claimed her history was backed up before a single record had left the phone")
    }

    func testAFailedExportIsNotCalledBackedUp() {
        health.ingestForTesting(type: .export, succeeded: false, endDate: Date())
        XCTAssertEqual(health.state, .notLeaving)
        XCTAssertFalse(line().contains("is backed up"),
            "every export is failing and Caelyn says her history is backed up — which is how a missing Production field looks from the inside")
    }

    func testAFailedSetupIsNotCalledBackedUp() {
        health.ingestForTesting(type: .setup, succeeded: false, endDate: Date())
        XCTAssertEqual(health.state, .notLeaving)
        XCTAssertFalse(line().contains("is backed up"))
    }

    func testASuccessfulExportIsWhatEarnsTheClaim() {
        health.ingestForTesting(type: .export, succeeded: true, endDate: Date())
        guard case .backedUp = health.state else {
            return XCTFail("a successful export did not register, so Caelyn will never tell her it worked")
        }
        XCTAssertTrue(line().contains("is backed up"))
    }

    /// Records arriving *down* from another device say nothing about whether hers
    /// went *up*.
    func testAnImportAloneDoesNotEarnTheClaim() {
        health.ingestForTesting(type: .import, succeeded: true, endDate: Date())
        XCTAssertFalse(line().contains("is backed up"),
            "a successful download was treated as proof that her own history had uploaded")
    }

    func testAnExportStillRunningIsNotYetTheClaim() {
        health.ingestForTesting(type: .export, succeeded: false, endDate: nil)
        XCTAssertEqual(health.state, .working)
        XCTAssertFalse(line().contains("is backed up"))
    }

    // MARK: - Not losing the claim once it is earned

    /// A long first sync emits a start event after a success. That must not read
    /// as having gone backwards.
    func testAnInFlightEventDoesNotUndoASuccessfulBackup() {
        health.ingestForTesting(type: .export, succeeded: true, endDate: Date())
        health.ingestForTesting(type: .export, succeeded: false, endDate: nil)
        guard case .backedUp = health.state else {
            return XCTFail("a new sync starting made Caelyn forget that her history had already uploaded")
        }
    }

    /// But a *finished* failure after a success is real news and must show.
    func testAFailureAfterASuccessIsReported() {
        health.ingestForTesting(type: .export, succeeded: true, endDate: Date())
        health.ingestForTesting(type: .export, succeeded: false, endDate: Date())
        XCTAssertEqual(health.state, .notLeaving,
            "sync stopped working and Caelyn kept saying everything was backed up")
    }

    // MARK: - What she reads

    /// Every state has to leave her certain her history is not lost. It never is:
    /// the store is on the phone in all of them.
    func testEveryStateReassuresHerTheDataIsOnThePhone() {
        let states: [CloudSyncHealth.State] = [.waiting, .working, .backedUp(Date()), .notLeaving]
        for state in states {
            let text = state.message(availability: .available)
            XCTAssertTrue(text.contains("this iPhone") || text.contains("is backed up"),
                "\(state) does not tell her where her history actually is: \(text)")
        }
    }

    /// CloudKit's vocabulary must never reach the screen.
    func testNoStateLeaksApplesVocabulary() {
        let states: [CloudSyncHealth.State] = [.waiting, .working, .backedUp(Date()), .notLeaving]
        let banned = ["CKError", "CloudKit", "CKAccountStatus", "NSPersistentCloudKit",
                      "error", "Error", "failed", "schema", "record type"]
        for state in states {
            let text = state.message(availability: .available)
            for word in banned {
                XCTAssertFalse(text.contains(word), "\(state) says \"\(word)\" to her: \(text)")
            }
        }
    }

    /// A problem reaching iCloud at all outranks anything the export log says —
    /// she needs to hear the actionable thing, and the existing copy says it.
    func testBeingSignedOutOfICloudStillTakesPrecedence() {
        health.ingestForTesting(type: .export, succeeded: true, endDate: Date())
        XCTAssertEqual(line(.noAccount), CloudAvailability.noAccount.message)
        XCTAssertEqual(line(.restricted), CloudAvailability.restricted.message)
        XCTAssertEqual(line(.unreachable), CloudAvailability.unreachable.message)
    }

    /// The claim has to survive a relaunch, or every cold start tells a long-time
    /// user that her history is not backed up yet.
    func testASuccessfulBackupIsRememberedAcrossLaunches() {
        let when = Date(timeIntervalSince1970: 1_780_000_000)
        health.ingestForTesting(type: .export, succeeded: true, endDate: when)
        XCTAssertEqual(
            UserDefaults.standard.object(forKey: "caelyn.cloud.lastSuccessfulExport") as? Date, when,
            "the successful backup was not recorded, so the next launch starts by telling her nothing has synced")
    }
}
