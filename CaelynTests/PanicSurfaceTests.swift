import SwiftData
import XCTest
@testable import Caelyn

/// The features that exist for the worst day must work on the worst day.
///
/// **What these protect.** Caelyn offers a duress PIN — a second PIN that, typed
/// instead of the real one, silently destroys everything and opens the app
/// looking brand new. Its whole purpose is the moment someone is standing over
/// her demanding she unlock it. The App Lock FAQ promises exactly that:
/// "entering it instead of your real PIN silently and permanently erases
/// everything — the app opens looking brand new, with no sign anything was
/// deleted."
///
/// A feature like that has no margin. There is no second attempt, no support
/// ticket, no undo. If it fails, it fails in the one situation where failing
/// matters, and she has already bet on it working.
@MainActor
final class DuressPINTests: XCTestCase {

    override func setUp() { super.setUp(); PINService.clearAll() }
    override func tearDown() { PINService.clearAll(); super.tearDown() }

    private func arm(primary: String = "1234", duress: String = "9999") {
        PINService.setPIN(primary)
        PINService.setDuressPIN(duress)
    }

    /// Someone has taken her phone and is trying PINs. Five wrong guesses start a
    /// lockout. She then gets a chance to type something — and types the duress
    /// PIN. That has to wipe.
    func testTheDuressPINStillWorksAfterSomeoneHasBeenGuessing() {
        arm()
        for _ in 0..<PINService.maxAttempts { _ = PINService.verify("0000") }

        // Sanity: the lockout is in force, which is correct for the real PIN.
        guard case .lockedOut = PINService.verify("1234") else {
            return XCTFail("the lockout did not engage, so this test is not testing what it thinks")
        }

        XCTAssertEqual(PINService.verify("9999"), .duress,
            "the duress PIN was refused because someone had already been guessing wrong ones — which is the only circumstance in which it is ever typed. The wipe does not happen, and she has been told it would.")
    }

    /// The lockout must still protect the real PIN.
    func testGuessingTheRealPINIsStillThrottled() {
        arm()
        for i in 0..<(PINService.maxAttempts - 1) {
            XCTAssertEqual(PINService.verify("0000"), .wrong(remaining: PINService.maxAttempts - 1 - i))
        }
        guard case .lockedOut = PINService.verify("0000") else {
            return XCTFail("brute-forcing the real PIN is no longer throttled")
        }
        guard case .lockedOut = PINService.verify("1234") else {
            return XCTFail("the lockout must hold for the real PIN even when it is correct")
        }
    }

    /// And a wrong PIN during a lockout must not become a free duress attempt.
    func testAWrongPINDuringLockoutIsStillRefused() {
        arm()
        for _ in 0..<PINService.maxAttempts { _ = PINService.verify("0000") }
        guard case .lockedOut = PINService.verify("5555") else {
            return XCTFail("checking duress first let an ordinary wrong guess through")
        }
    }

    func testTheDuressPINResetsTheLockoutSoTheFreshAppIsUsable() {
        arm()
        for _ in 0..<PINService.maxAttempts { _ = PINService.verify("0000") }
        XCTAssertEqual(PINService.verify("9999"), .duress)
        // After the wipe she is in a brand-new app. A lockout left in place would
        // be a visible trace that something happened here.
        XCTAssertEqual(PINService.verify("0000"), .wrong(remaining: PINService.maxAttempts - 1))
    }

    func testTheRealPINStillUnlocksNormally() {
        arm()
        XCTAssertEqual(PINService.verify("1234"), .correct)
    }

    func testWithNoDuressPINSetNothingChanges() {
        PINService.setPIN("1234")
        XCTAssertEqual(PINService.verify("1234"), .correct)
        XCTAssertEqual(PINService.verify("9999"), .wrong(remaining: PINService.maxAttempts - 1))
    }

    // MARK: - It must be reachable

    /// A duress PIN is typed into the lock screen. With App Lock off there is no
    /// lock screen, so there is no way to type it: `AppLockGate` returns early on
    /// `lockEnabled` before it ever reaches the PIN pad.
    ///
    /// Arming it in that state hands her a safety feature that silently is not
    /// one — and she finds out when it matters.
    func testArmingADuressPINRequiresTheLockToBeOn() {
        XCTAssertFalse(PINSettingsPolicy.canArmDuressPIN(lockEnabled: false, pinIsSet: true),
            "she can arm a duress wipe while App Lock is off, so the PIN pad never appears and the wipe can never be triggered")
        XCTAssertTrue(PINSettingsPolicy.canArmDuressPIN(lockEnabled: true, pinIsSet: true))
    }

    func testADuressPINNeedsARealPINToHideBehind() {
        XCTAssertFalse(PINSettingsPolicy.canArmDuressPIN(lockEnabled: true, pinIsSet: false))
    }

    /// Switching App Lock off while a duress PIN is armed is the same hole arrived
    /// at from the other direction, and she has to be told rather than left to
    /// assume.
    func testTurningTheLockOffWhileADuressPINIsArmedWarnsHer() {
        XCTAssertTrue(PINSettingsPolicy.needsDuressWarningWhenDisablingLock(hasDuressPIN: true))
        XCTAssertFalse(PINSettingsPolicy.needsDuressWarningWhenDisablingLock(hasDuressPIN: false))
    }
}

/// Auto-erase destroys everything on a timer, so where it is stored and how it
/// is armed both matter more than for any other setting.
@MainActor
final class AutoEraseTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        AutoSweepSettings.forget()
        container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        context = container.mainContext
    }
    override func tearDownWithError() throws {
        AutoSweepSettings.forget()
        container = nil; context = nil
    }

    private func profiles() -> [UserProfile] {
        (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
    }

    // MARK: - It must not sync

    /// `UserProfile` is a mirrored record. A synced auto-erase means a spare iPad
    /// in a drawer can pass its window, wipe itself, and export those deletions
    /// to her iCloud — which propagates them to the phone she uses every day.
    func testAutoEraseIsNotStoredOnTheSyncedProfile() {
        AutoSweepSettings.isEnabled = true
        let profile = UserProfile()
        context.insert(profile)
        context.saveOrLog()

        XCTAssertFalse(profile.autoWipeEnabled,
            "arming auto-erase wrote to the mirrored profile, so it syncs to every device she owns and each one can wipe the others")
    }

    /// A profile arriving from another device must not arm it here.
    func testAProfileArrivingWithAutoEraseOnDoesNotArmThisDevice() {
        // First launch after the handover: adopt runs once, with nothing on.
        AutoSweepSettings.adoptProfileSettingIfNeeded(nil)
        XCTAssertFalse(AutoSweepSettings.isEnabled)

        // Now a profile syncs in with it switched on elsewhere.
        let synced = UserProfile()
        synced.autoWipeEnabled = true
        synced.autoWipeAfterDays = 1
        context.insert(synced)
        context.saveOrLog()
        AutoSweepSettings.adoptProfileSettingIfNeeded(synced)

        XCTAssertFalse(AutoSweepSettings.isEnabled,
            "a profile synced from another device armed a destruct timer on this one")
    }

    /// But a choice she made before it was device-local has to carry over, or the
    /// upgrade silently disarms a safety feature she is relying on.
    func testHerExistingChoiceIsCarriedOverExactlyOnce() {
        let profile = UserProfile()
        profile.autoWipeEnabled = true
        profile.autoWipeAfterDays = 7
        profile.lastActiveAt = Date(timeIntervalSince1970: 1_000_000)
        context.insert(profile)
        context.saveOrLog()

        AutoSweepSettings.adoptProfileSettingIfNeeded(profile)
        XCTAssertTrue(AutoSweepSettings.isEnabled, "her armed auto-erase was silently switched off by the upgrade")
        XCTAssertEqual(AutoSweepSettings.afterDays, 7, "her window length changed")
        XCTAssertEqual(AutoSweepSettings.lastActiveAt, Date(timeIntervalSince1970: 1_000_000),
            "measuring from today would quietly extend the window she set")

        // And she can then turn it off without the profile turning it back on.
        AutoSweepSettings.isEnabled = false
        AutoSweepSettings.adoptProfileSettingIfNeeded(profile)
        XCTAssertFalse(AutoSweepSettings.isEnabled, "turning it off did not stick")
    }

    // MARK: - The window

    func testADeviceThatHasNeverRecordedActivityDoesNotWipeOnFirstLaunch() async {
        AutoSweepSettings.isEnabled = true
        AutoSweepSettings.afterDays = 7
        let profile = UserProfile()
        profile.preferredName = "Sam"
        context.insert(profile)
        context.saveOrLog()

        let wiped = await AutoSweepService.checkAndSweep(profile: profile, modelContext: context)
        XCTAssertFalse(wiped, "a missing activity stamp read as 'idle since 1970' and wiped her on first launch")
        XCTAssertEqual(profiles().count, 1)
    }

    func testTheWindowStillFiresWhenItHasActuallyElapsed() async {
        AutoSweepSettings.isEnabled = true
        AutoSweepSettings.afterDays = 7
        AutoSweepSettings.lastActiveAt = Date(timeIntervalSince1970: 1_780_000_000)
        let profile = UserProfile()
        context.insert(profile)
        let entry = CycleEntry(date: Date(timeIntervalSince1970: 1_780_000_000))
        entry.flow = .medium
        context.insert(entry)
        context.saveOrLog()

        let wiped = await AutoSweepService.checkAndSweep(
            profile: profile, modelContext: context,
            now: Date(timeIntervalSince1970: 1_780_000_000 + 8 * 86_400))
        XCTAssertTrue(wiped, "the window elapsed and nothing happened")
        XCTAssertTrue(profiles().isEmpty)
    }

    func testAnUnarmedDeviceNeverWipes() async {
        AutoSweepSettings.lastActiveAt = Date(timeIntervalSince1970: 1)
        let profile = UserProfile()
        context.insert(profile)
        context.saveOrLog()
        let wiped = await AutoSweepService.checkAndSweep(profile: profile, modelContext: context)
        XCTAssertFalse(wiped)
        XCTAssertEqual(profiles().count, 1)
    }

    // MARK: - Not resurrecting what it just deleted

    /// `recordActivity` used to run on the line after the sweep, holding the
    /// profile the sweep had just deleted. Writing to a deleted `@Model` object
    /// can bring the row back — and a resurrected `UserProfile` carries her name,
    /// her averages, her Pro flag and her lock settings, in a store that was meant
    /// to look brand new. On a mirrored container it exports that too.
    func testAWipeIsNotUndoneByStampingActivityAfterwards() async {
        AutoSweepSettings.isEnabled = true
        AutoSweepSettings.afterDays = 1
        AutoSweepSettings.lastActiveAt = Date(timeIntervalSince1970: 1_780_000_000)
        let profile = UserProfile()
        profile.preferredName = "Sam"
        profile.isPro = true
        context.insert(profile)
        context.saveOrLog()

        let wiped = await AutoSweepService.checkAndSweep(
            profile: profile, modelContext: context,
            now: Date(timeIntervalSince1970: 1_780_000_000 + 5 * 86_400))
        XCTAssertTrue(wiped)

        // What `AppLockGate` does now: skip the stamp when the sweep fired.
        if !wiped { AutoSweepService.recordActivity() }
        context.saveOrLog()

        XCTAssertTrue(profiles().isEmpty,
            "the wipe left a UserProfile behind — her name, averages and Pro flag survived a wipe that promised to leave nothing")
    }

    /// And the fresh app must not arrive with the timer still armed.
    func testAWipeDisarmsAutoErase() async {
        AutoSweepSettings.isEnabled = true
        AutoSweepSettings.afterDays = 3
        await SecureWipeService.wipeEverything(modelContext: context)
        XCTAssertFalse(AutoSweepSettings.isEnabled,
            "the app she is handed back still has a destruct timer running on it")
    }
}

/// A wipe must not leave her history in a file.
@MainActor
final class WipeResidueTests: XCTestCase {

    private var scratch: URL!
    private var tmp: URL!

    override func setUpWithError() throws {
        let fm = FileManager.default
        scratch = fm.temporaryDirectory.appending(path: "wipe-residue-\(UUID().uuidString)")
        tmp = scratch.appending(path: "tmp")
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func write(_ name: String, into dir: URL) throws -> URL {
        let url = dir.appending(path: name)
        try Data("2026-06-01,heavy,cramps,headache".utf8).write(to: url)
        return url
    }

    func testAnExportLeftInTheTemporaryDirectoryIsRemoved() throws {
        let csv = try write("Caelyn-all-2026-10-05.csv", into: tmp)
        let pdf = try write("Caelyn-3mo-2026-10-05.pdf", into: tmp)

        SecureWipeService.removeStoredFiles(temporaryDirectory: tmp, applicationSupport: scratch)

        XCTAssertFalse(FileManager.default.fileExists(atPath: csv.path),
            "a full CSV export of her history was still sitting in the temporary directory after she asked for everything to be deleted")
        XCTAssertFalse(FileManager.default.fileExists(atPath: pdf.path))
    }

    func testAPreservedCorruptStoreIsRemoved() throws {
        let store = try write("default.store.corrupt-1780000000", into: scratch)
        let wal = try write("default.store.corrupt-1780000000-wal", into: scratch)
        let shm = try write("default.store.corrupt-1780000000-shm", into: scratch)

        SecureWipeService.removeStoredFiles(temporaryDirectory: tmp, applicationSupport: scratch)

        for url in [store, wal, shm] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                "\(url.lastPathComponent) survived — a complete SQLite copy of her history, which nothing deletes and no screen offers her")
        }
    }

    func testTheImportLedgerIsRemoved() throws {
        let ledger = try write("CaelynImportLedger.json", into: scratch)
        SecureWipeService.removeStoredFiles(temporaryDirectory: tmp, applicationSupport: scratch)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ledger.path),
            "the ledger records which days carried which fields, which is enough to reconstruct the shape of her cycle")
    }

    /// Someone else's files in the same directories are not ours to delete.
    func testNothingElseIsTouched() throws {
        let theirs = try write("SomeOtherApp.sqlite", into: scratch)
        let alsoTheirs = try write("unrelated.txt", into: tmp)
        let live = try write("default.store", into: scratch)

        SecureWipeService.removeStoredFiles(temporaryDirectory: tmp, applicationSupport: scratch)

        for url in [theirs, alsoTheirs] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                "\(url.lastPathComponent) was deleted and it is not Caelyn's")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: live.path),
            "the live store was deleted by the filename sweep rather than through SwiftData")
    }

    func testMissingDirectoriesAreNotAProblem() {
        let gone = scratch.appending(path: "does-not-exist")
        SecureWipeService.removeStoredFiles(temporaryDirectory: gone, applicationSupport: gone)
    }
}
