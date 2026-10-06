import SwiftData
import WatchConnectivity
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

    /// Her normal PIN must never become the duress PIN. `verify` checks duress
    /// first, so changing her PIN to the duress digits would turn every ordinary
    /// unlock into a silent, total wipe.
    func testHerNormalPINCanNeverBeTheDuressDigits() {
        arm()
        XCTAssertFalse(PINService.setPIN("9999"),
            "changing her PIN to the duress digits was accepted — her next ordinary unlock erases everything")
        XCTAssertEqual(PINService.verify("1234"), .correct, "the refused change must leave her real PIN in place")
    }

    /// And the other way round — including during a lockout, where `verify`
    /// would have answered `.lockedOut` and let a colliding duress PIN through.
    func testTheDuressPINCanNeverBeHerNormalDigits() {
        PINService.setPIN("1234")
        for _ in 0..<PINService.maxAttempts { _ = PINService.verify("0000") }
        XCTAssertFalse(PINService.setDuressPIN("1234"),
            "a duress PIN equal to her normal PIN was armed")
        XCTAssertFalse(PINService.hasDuress)
    }

    /// Checking for a collision must not cost her an attempt.
    func testCheckingForACollisionCountsNoFailedAttempts() {
        arm()
        for _ in 0..<(PINService.maxAttempts * 2) { _ = PINService.matches("5555", duress: false) }
        XCTAssertEqual(PINService.verify("1234"), .correct,
            "the collision check counted failures and locked her out of her own app")
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
        AutoSweepSettings.resetForTesting()
        container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        context = container.mainContext
    }
    override func tearDownWithError() throws {
        AutoSweepSettings.resetForTesting()
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
        AutoSweepSettings.adoptProfileSettingIfNeeded(nil, syncEnabled: false)
        XCTAssertFalse(AutoSweepSettings.isEnabled)

        // Now a profile syncs in with it switched on elsewhere.
        let synced = UserProfile()
        synced.autoWipeEnabled = true
        synced.autoWipeAfterDays = 1
        context.insert(synced)
        context.saveOrLog()
        AutoSweepSettings.adoptProfileSettingIfNeeded(synced, syncEnabled: false)

        XCTAssertFalse(AutoSweepSettings.isEnabled,
            "a profile synced from another device armed a destruct timer on this one")
    }

    /// With sync on, the profile may carry another device's choice and another
    /// device's activity — the spare-iPad wipe this type exists to prevent.
    func testAnUpgradeWithSyncOnDoesNotAdoptAMirroredTimer() {
        let synced = UserProfile()
        synced.autoWipeEnabled = true
        synced.autoWipeAfterDays = 30
        context.insert(synced)
        context.saveOrLog()
        AutoSweepSettings.adoptProfileSettingIfNeeded(synced, syncEnabled: true)
        XCTAssertFalse(AutoSweepSettings.isEnabled,
            "an upgrading device adopted a destruct timer from the mirrored profile")
    }

    /// A wipe must not reopen adoption: a profile synced back in afterwards would
    /// re-arm with a stamp whose window has already run out.
    func testAWipeDoesNotReopenAdoption() {
        AutoSweepSettings.adoptProfileSettingIfNeeded(nil, syncEnabled: false)
        AutoSweepSettings.forget()                     // what a wipe does
        let returning = UserProfile()
        returning.autoWipeEnabled = true
        returning.autoWipeAfterDays = 1
        returning.lastActiveAt = Date(timeIntervalSince1970: 1_000_000)
        context.insert(returning)
        context.saveOrLog()
        AutoSweepSettings.adoptProfileSettingIfNeeded(returning, syncEnabled: false)
        XCTAssertFalse(AutoSweepSettings.isEnabled,
            "a wiped device re-armed itself from a profile that came back, with an elapsed window")
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

        AutoSweepSettings.adoptProfileSettingIfNeeded(profile, syncEnabled: false)
        XCTAssertTrue(AutoSweepSettings.isEnabled, "her armed auto-erase was silently switched off by the upgrade")
        XCTAssertEqual(AutoSweepSettings.afterDays, 7, "her window length changed")
        XCTAssertEqual(AutoSweepSettings.lastActiveAt, Date(timeIntervalSince1970: 1_000_000),
            "measuring from today would quietly extend the window she set")

        // And she can then turn it off without the profile turning it back on.
        AutoSweepSettings.isEnabled = false
        AutoSweepSettings.adoptProfileSettingIfNeeded(profile, syncEnabled: false)
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

/// App Lock belongs to the device in her hand. A synced toggle from another
/// device must not switch it off — the lock screen is the only place a duress
/// PIN armed on this device can be typed.
@MainActor
final class DeviceLocalLockTests: XCTestCase {

    override func setUp() { super.setUp(); AppLockSettings.resetForTesting() }
    override func tearDown() { AppLockSettings.resetForTesting(); super.tearDown() }

    /// Upgrading from a build that kept the lock on the profile must not unlock her.
    func testAnUpgradingUserWithTheLockOnIsStillLocked() {
        let profile = UserProfile()
        profile.lockEnabled = true
        XCTAssertTrue(AppLockSettings.isEnabled(profile: profile),
            "the upgrade opened an App Lock user's history without asking")
    }

    /// The case this exists for: she turns the lock off on her iPad, it syncs.
    func testASyncedLockOffFromAnotherDeviceDoesNotUnlockThisOne() {
        let profile = UserProfile()
        profile.lockEnabled = true
        XCTAssertTrue(AppLockSettings.isEnabled(profile: profile))   // adopted here

        profile.lockEnabled = false                                   // arrives via iCloud
        XCTAssertTrue(AppLockSettings.isEnabled(profile: profile),
            "another device switched this phone's lock off — and with it the only place her duress PIN can be typed")
    }

    /// No profile yet (first launch, mid-onboarding) decides nothing.
    func testNoProfileDecidesNothing() {
        XCTAssertFalse(AppLockSettings.isEnabled(profile: nil))
        XCTAssertNil(UserDefaults.standard.object(forKey: AppLockSettings.key))
    }

    /// After a wipe, a profile still held on screen — or one syncing back in —
    /// must not lock the app she was handed back.
    func testAProfileSeenAfterAWipeCannotRelockTheApp() {
        let profile = UserProfile()
        profile.lockEnabled = true
        XCTAssertTrue(AppLockSettings.isEnabled(profile: profile))
        AppLockSettings.forget()                                 // what a wipe does
        XCTAssertFalse(AppLockSettings.isEnabled(profile: profile),
            "the wiped app re-locked itself from a profile that should no longer count")
    }

    /// A wipe hands back an app that opens unlocked, like a new install.
    func testAWipeForgetsTheLock() async throws {
        AppLockSettings.setEnabled(true)
        let container = try ModelContainer(for: Persistence.schema,
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        await SecureWipeService.wipeEverything(modelContext: container.mainContext)
        XCTAssertFalse(AppLockSettings.isEnabled(profile: nil))
    }
}

/// A wipe has to reach her wrist even when the watch cannot hear it yet.
@MainActor
final class WatchClearTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: WatchBridgeService.pendingClearKey)
        super.tearDown()
    }

    /// The launch sweep runs before the session activates. The clear used to be
    /// dropped on the floor; it must be kept and sent when the session is ready.
    func testAClearTheWatchCannotReceiveYetIsKeptForLater() throws {
        if WCSession.isSupported(), WCSession.default.activationState == .activated,
           WCSession.default.isWatchAppInstalled {
            throw XCTSkip("a reachable watch app takes the clear immediately")
        }
        WatchBridgeService.shared.pushCleared(at: Date(timeIntervalSince1970: 42))
        XCTAssertEqual(UserDefaults.standard.object(forKey: WatchBridgeService.pendingClearKey) as? TimeInterval, 42,
            "a wipe the watch could not hear yet was forgotten — her cycle stays on her wrist")
    }
}
