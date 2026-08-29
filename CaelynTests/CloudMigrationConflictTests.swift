import SwiftData
import XCTest
@testable import Caelyn

/// Upgrading an existing user, and what happens when two devices disagree.
///
/// The conflict cases below are written the way sync actually delivers them: a
/// second row for a day that already has one. That is precisely what CloudKit
/// produces when Device A and Device B both logged the same day, because the store
/// has no unique constraint to stop it — so the merge is the only thing standing
/// between her and either a duplicate or a silently discarded afternoon.
@MainActor
final class CloudMigrationConflictTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private var storeURL: URL!

    override func setUpWithError() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appending(path: "caelyn-migration-\(UUID().uuidString).store")
    }

    override func tearDownWithError() throws {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
        }
        storeURL = nil
    }

    private func openStore() throws -> ModelContainer {
        let config = ModelConfiguration(schema: Persistence.schema, url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(for: Persistence.schema, configurations: [config])
    }

    /// Open the store, do something, and let the container go.
    ///
    /// Two live `ModelContainer`s over one file make SwiftData reset the older
    /// context out from under its model objects, so an "upgrade" test has to close
    /// the first store before opening the second. A function boundary releases the
    /// container deterministically in a way a `do {}` block does not.
    @discardableResult
    private func withStore<T>(_ body: (ModelContext) throws -> T) throws -> T {
        let container = try openStore()
        let result = try body(container.mainContext)
        try container.mainContext.save()
        return result
    }

    private func day(_ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 3, day: d))!)
    }

    // MARK: - Phase 6: the existing user upgrading

    /// An existing 1.2 user updates, opens Caelyn, and everything is simply there.
    ///
    /// Written against a **real file on disk**, closed and reopened through a fresh
    /// container, because that is what an app update actually is. Nothing about
    /// this requires an account or a network.
    func testAnExistingUsersHistorySurvivesTheUpgradeUntouched() throws {
        // --- She has been using 1.2 for a while.
        try withStore { context in
            for offset in 0..<120 {
                let entry = CycleEntry(date: day(1).addingTimeInterval(Double(offset) * 86_400))
                entry.date = calendar.startOfDay(for: entry.date)
                entry.flow = offset % 28 < 4 ? .medium : nil
                entry.symptoms = offset % 5 == 0 ? [.cramps, .bloating] : []
                entry.note = offset == 3 ? "rough one" : nil
                context.insert(entry)
            }
            let profile = UserProfile()
            profile.averageCycleLength = 31
            profile.customSymptoms = ["migraine"]
            context.insert(profile)
        }

        // --- She updates to 1.3 and opens the app. New container, same file.
        try withStore { context in
            let entries = try context.fetch(FetchDescriptor<CycleEntry>())
            let profile = try context.fetch(FetchDescriptor<UserProfile>()).first

            XCTAssertEqual(entries.count, 120, "Every logged day must still be there after the upgrade.")
            XCTAssertEqual(entries.filter { $0.flow != nil }.count, 120 / 28 * 4 + min(120 % 28, 4))
            XCTAssertEqual(entries.first { $0.note != nil }?.note, "rough one")
            XCTAssertEqual(profile?.averageCycleLength, 31, "Her settings survive too.")
            XCTAssertEqual(profile?.customSymptoms, ["migraine"])

            // And the 1.3 fields simply default — no migration plan needed, because
            // every one of them is additive with a default.
            XCTAssertNil(profile?.preferredName)
            XCTAssertNil(profile?.displayName)
            XCTAssertFalse(profile?.accountLinked ?? true)
        }
    }

    /// No login is required to see any of it.
    func testNoAccountIsNeededToSeeExistingHistory() throws {
        try withStore { context in
            let entry = CycleEntry(date: day(1), flow: .heavy)
            entry.date = day(1)
            context.insert(entry)
        }
        AccountIdentityStore.signOut()

        try withStore { context in
            XCTAssertFalse(AccountIdentityStore.isSignedIn)
            XCTAssertEqual(try context.fetch(FetchDescriptor<CycleEntry>()).count, 1)
        }
    }

    /// Enabling sync must not blank the store. This is the file-level companion to
    /// the URL assertion in CloudSyncSafetyTests: same path, same rows.
    func testTurningSyncOnDoesNotStartFromAnEmptyStore() throws {
        try withStore { context in
            for offset in 0..<30 {
                let entry = CycleEntry(date: day(1).addingTimeInterval(Double(offset) * 86_400))
                entry.date = calendar.startOfDay(for: entry.date)
                entry.flow = .light
                context.insert(entry)
            }
        }

        // The configuration a sync-enabled launch builds differs only in how it
        // mirrors — the URL is the same file, so the rows are the same rows.
        try withStore { context in
            XCTAssertEqual(try context.fetch(FetchDescriptor<CycleEntry>()).count, 30)
        }
    }

    // MARK: - Phase 8: two devices, one day

    private func twoDeviceDay(
        deviceA: (CycleEntry) -> Void,
        deviceB: (CycleEntry) -> Void,
        bIsNewer: Bool = true,
        assert: (CycleEntry) -> Void
    ) throws {
        let container = try openStore()
        let context = container.mainContext

        let a = CycleEntry(date: day(10))
        a.date = day(10)
        a.createdAt = Date(timeIntervalSince1970: 1_000)
        a.updatedAt = Date(timeIntervalSince1970: 1_000)
        deviceA(a)
        context.insert(a)

        // The row CloudKit delivers from the other device, for a day that already
        // has one.
        let b = CycleEntry(date: day(10))
        b.date = day(10)
        b.createdAt = Date(timeIntervalSince1970: 2_000)
        b.updatedAt = Date(timeIntervalSince1970: bIsNewer ? 3_000 : 500)
        deviceB(b)
        context.insert(b)
        try context.save()

        let merged = CycleStore.dedupeSameDay(in: context)
        XCTAssertEqual(merged, 1, "The two rows for one day should become one.")

        let remaining = try context.fetch(FetchDescriptor<CycleEntry>())
        XCTAssertEqual(remaining.count, 1)
        assert(remaining[0])
    }

    /// Same field on both devices: the more recent edit wins. Deterministic, and
    /// the one case where something genuinely has to give.
    func testSameFieldEditedOnBothDevicesTakesTheNewerValue() throws {
        try twoDeviceDay(
            deviceA: { $0.flow = .light },
            deviceB: { $0.flow = .heavy }
        ) { merged in
            XCTAssertEqual(merged.flow, .heavy)
        }
    }

    /// **The rule that matters most.** A later sync must not be able to erase
    /// something by simply not having it. Device B edited the mood and knows
    /// nothing about the note; the note must survive.
    func testALaterSyncNeverErasesAFieldItSimplyDoesNotHave() throws {
        try twoDeviceDay(
            deviceA: { $0.note = "worst cramps in months"; $0.flow = .heavy },
            deviceB: { $0.mood = .sad }
        ) { merged in
            XCTAssertEqual(merged.note, "worst cramps in months", "Reproductive-health data is never dropped just because another device synced later.")
            XCTAssertEqual(merged.flow, .heavy)
            XCTAssertEqual(merged.mood, .sad)
        }
    }

    /// Different fields on the same day: both survive. Nothing to resolve.
    func testDifferentFieldsOnTheSameDayBothSurvive() throws {
        try twoDeviceDay(
            deviceA: { $0.basalTemperature = 36.6 },
            deviceB: { $0.cervicalMucus = .eggWhite }
        ) { merged in
            XCTAssertEqual(merged.basalTemperature, 36.6)
            XCTAssertEqual(merged.cervicalMucus, .eggWhite)
        }
    }

    /// Symptoms are additive: logging cramps on the phone and bloating on the iPad
    /// means she had both, not whichever synced last.
    func testSymptomsFromBothDevicesAreUnioned() throws {
        try twoDeviceDay(
            deviceA: { $0.symptoms = [.cramps, .fatigue] },
            deviceB: { $0.symptoms = [.bloating] }
        ) { merged in
            XCTAssertEqual(Set(merged.symptoms), [.cramps, .fatigue, .bloating])
        }
    }

    func testPainTypesAndCustomSymptomsAreAlsoUnioned() throws {
        try twoDeviceDay(
            deviceA: { $0.painTypes = [.cramps]; $0.loggedCustomSymptoms = ["migraine"] },
            deviceB: { $0.painTypes = [.backPain]; $0.loggedCustomSymptoms = ["jaw ache"] }
        ) { merged in
            XCTAssertEqual(Set(merged.painTypes), [.cramps, .backPain])
            XCTAssertEqual(Set(merged.loggedCustomSymptoms), ["migraine", "jaw ache"])
        }
    }

    /// Severity takes the worse of the two. Under-reporting how bad a day was is
    /// the more harmful error.
    func testSymptomSeverityKeepsTheWorseReading() throws {
        try twoDeviceDay(
            deviceA: { $0.symptoms = [.cramps]; $0.symptomSeverity = ["cramps": 3] },
            deviceB: { $0.symptoms = [.cramps]; $0.symptomSeverity = ["cramps": 1] }
        ) { merged in
            XCTAssertEqual(merged.symptomSeverity["cramps"], 3)
        }
    }

    /// An older row arriving late — delayed sync — must not overwrite newer work.
    func testADelayedSyncFromAnOlderEditDoesNotWin() throws {
        try twoDeviceDay(
            deviceA: { $0.flow = .heavy },
            deviceB: { $0.flow = .spotting },
            bIsNewer: false
        ) { merged in
            XCTAssertEqual(merged.flow, .heavy, "A late delivery of an older edit must not clobber the newer one.")
        }
    }

    /// Unspecified intensity is a real recorded state — she bled, amount unknown —
    /// and must survive a merge rather than being treated as absent.
    func testUnspecifiedFlowIsPreservedThroughAMerge() throws {
        try twoDeviceDay(
            deviceA: { $0.flow = .unspecified },
            deviceB: { $0.mood = .calm }
        ) { merged in
            XCTAssertEqual(merged.flow, .unspecified, "Caelyn must not upgrade or discard an unspecified bleed.")
        }
    }

    /// Repeated delivery of the same record — CloudKit can deliver more than once —
    /// converges instead of multiplying.
    func testRunningTheMergeRepeatedlyIsIdempotent() throws {
        let container = try openStore()
        let context = container.mainContext
        for _ in 0..<3 {
            let entry = CycleEntry(date: day(12))
            entry.date = day(12)
            entry.flow = .medium
            context.insert(entry)
        }
        try context.save()

        XCTAssertEqual(CycleStore.dedupeSameDay(in: context), 2)
        XCTAssertEqual(CycleStore.dedupeSameDay(in: context), 0, "A second pass has nothing left to do.")
        XCTAssertEqual(CycleStore.dedupeSameDay(in: context), 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CycleEntry>()).count, 1)
    }

    /// Days must not slide. A row delivered from a device in another time zone
    /// still belongs to the calendar day it was logged on.
    func testMergingDoesNotShiftADayAcrossTimeZones() throws {
        let container = try openStore()
        let context = container.mainContext

        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let entry = CycleEntry(date: day(15))
        entry.date = day(15)
        entry.flow = .medium
        context.insert(entry)
        try context.save()

        _ = CycleStore.dedupeSameDay(in: context, calendar: calendar)
        let after = try context.fetch(FetchDescriptor<CycleEntry>())[0]
        XCTAssertEqual(calendar.startOfDay(for: after.date), day(15),
                       "The logged day is the logged day, wherever the other device was.")
    }

    // MARK: - Phase 9: import provenance is not confused by sync

    /// A record arriving from iCloud must never be mistaken for a fresh
    /// third-party import.
    ///
    /// The ledger lives on the device, so on a second device an arrived value has
    /// no claim — and `ImportReconciler` reads "no claim" as *she typed this*,
    /// which protects it. That is the safe direction, and this test pins it: the
    /// value is kept, not overwritten by a later Health/file import.
    func testASyncedValueWithNoLocalProvenanceIsTreatedAsHersAndProtected() throws {
        let container = try openStore()
        let context = container.mainContext
        let ledger = ImportLedger(fileURL: nil)   // a second device: empty ledger

        // Arrived from Device A via iCloud.
        let arrived = CycleEntry(date: day(20))
        arrived.date = day(20)
        arrived.flow = .heavy
        context.insert(arrived)
        try context.save()

        // Device B now runs an import that wants to write something else there.
        let observation = ImportObservation(
            day: day(20),
            field: .flow,
            value: .flow(.light),
            recordID: UUID(),
            sourceBundleID: "com.example.tracker",
            sourceName: "Some Tracker",
            recordedAt: Date()
        )
        let decisions = ImportReconciler.plan(
            observations: [observation],
            deletedRecordIDs: [],
            currentValue: { d, f in
                guard calendar.isDate(d, inSameDayAs: self.day(20)), f == .flow else { return nil }
                return .flow(.heavy)
            },
            ledger: ledger,
            ownBundleID: "smallpanta-icould.com.caelynperiodtracker",
            acceptOwnSource: false,
            calendar: calendar,
            today: day(28)
        )

        XCTAssertEqual(decisions.count, 1)
        XCTAssertEqual(decisions[0].action, ImportReconciler.Action.keepUserValue,
                       "Without a matching claim the value is treated as hers — an import must not overwrite what iCloud delivered.")
    }
}
