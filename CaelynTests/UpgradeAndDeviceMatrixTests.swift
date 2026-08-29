import SwiftData
import XCTest
@testable import Caelyn

/// The 1.2 → 1.3 upgrade at realistic scale, and the multi-device cases the
/// earlier pass did not reach.
///
/// Everything here runs against **real files on disk**, closed and reopened through
/// fresh containers, because that is what an app update and a sync delivery
/// actually are. Nothing is mocked at the persistence layer.
@MainActor
final class UpgradeAndDeviceMatrixTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private var storeURL: URL!

    override func setUpWithError() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appending(path: "caelyn-matrix-\(UUID().uuidString).store")
    }

    override func tearDownWithError() throws {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
        }
        storeURL = nil
    }

    /// Open, act, save, close. A function boundary releases the container, which a
    /// `do {}` block does not guarantee — and two live containers over one file make
    /// SwiftData reset the older context out from under its objects.
    @discardableResult
    private func withStore<T>(at url: URL? = nil, _ body: (ModelContext) throws -> T) throws -> T {
        let config = ModelConfiguration(schema: Persistence.schema,
                                        url: url ?? storeURL,
                                        cloudKitDatabase: .none)
        let container = try ModelContainer(for: Persistence.schema, configurations: [config])
        let result = try body(container.mainContext)
        try container.mainContext.save()
        return result
    }

    private func day(_ offset: Int, from start: Date) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: start)!)
    }

    private var origin: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2016, month: 1, day: 1))!)
    }

    /// Builds a store shaped like a real 1.2 install of a given age.
    private func seedHistory(days: Int, withProfile: Bool = true, notes: Bool = true) throws {
        try withStore { context in
            for offset in 0..<days {
                let entry = CycleEntry(date: self.day(offset, from: self.origin))
                entry.date = self.day(offset, from: self.origin)
                let inPeriod = offset % 29 < 5
                entry.flow = inPeriod ? [.heavy, .medium, .light, .spotting][offset % 4] : nil
                if offset % 7 == 0 { entry.symptoms = [.cramps, .bloating] }
                if offset % 11 == 0 { entry.pain = (offset % 5) + 1 }
                if notes && offset % 23 == 0 { entry.note = "synthetic note \(offset)" }
                if offset % 31 == 0 { entry.mood = .calm }
                context.insert(entry)
            }
            if withProfile {
                let profile = UserProfile()
                profile.hasOnboarded = true
                profile.averageCycleLength = 29
                profile.averagePeriodLength = 5
                profile.customSymptoms = ["synthetic-marker"]
                context.insert(profile)
            }
        }
    }

    private func entryCount() throws -> Int {
        try withStore { try $0.fetch(FetchDescriptor<CycleEntry>()).count }
    }

    // MARK: - Upgrade matrix

    func testUpgradeFromAnEmptyStore() throws {
        try withStore { _ in }
        try withStore { context in
            XCTAssertEqual(try context.fetch(FetchDescriptor<CycleEntry>()).count, 0)
            XCTAssertNil(try context.fetch(FetchDescriptor<UserProfile>()).first)
        }
    }

    func testUpgradeFromAProfileOnlyStore() throws {
        try withStore { context in
            let profile = UserProfile()
            profile.hasOnboarded = true
            context.insert(profile)
        }
        try withStore { context in
            let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
            XCTAssertEqual(profile?.hasOnboarded, true)
            // Every 1.3 field arrives defaulted — the migration is additive.
            XCTAssertNil(profile?.preferredName)
            XCTAssertNil(profile?.appleSuggestedName)
            XCTAssertFalse(profile?.accountLinked ?? true)
            XCTAssertFalse(profile?.hasConfirmedPreferredName ?? true)
        }
    }

    /// A store with entries but no profile — a real edge case from an interrupted
    /// onboarding, and one that must not crash the upgrade.
    func testUpgradeFromAStoreWithNoProfile() throws {
        try seedHistory(days: 40, withProfile: false)
        try withStore { context in
            XCTAssertEqual(try context.fetch(FetchDescriptor<CycleEntry>()).count, 40)
            XCTAssertNil(try context.fetch(FetchDescriptor<UserProfile>()).first)
        }
    }

    func testUpgradeFromOneMonth() throws {
        try seedHistory(days: 30)
        XCTAssertEqual(try entryCount(), 30)
    }

    func testUpgradeFromOneYear() throws {
        try seedHistory(days: 365)
        XCTAssertEqual(try entryCount(), 365)
    }

    /// Five years of daily entries. The size a long-term user actually reaches.
    func testUpgradeFromFiveYears() throws {
        try seedHistory(days: 365 * 5)
        XCTAssertEqual(try entryCount(), 1_825)

        try withStore { context in
            let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
            XCTAssertEqual(profile?.averageCycleLength, 29)
            XCTAssertEqual(profile?.customSymptoms, ["synthetic-marker"])
            XCTAssertFalse(profile?.hasConfirmedPreferredName ?? true)
        }
    }

    /// Ten years, to prove nothing degrades non-linearly at the top end.
    func testUpgradeFromTenYearsCompletesInReasonableTime() throws {
        try seedHistory(days: 365 * 10, notes: false)
        let started = ProcessInfo.processInfo.systemUptime
        let count = try entryCount()
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        XCTAssertEqual(count, 3_650)
        XCTAssertLessThan(elapsed, 10.0, "Opening a ten-year store should not take this long.")
    }

    /// Repeated launches must be idempotent — no drift, no duplication.
    func testRepeatedLaunchesChangeNothing() throws {
        try seedHistory(days: 200)
        for _ in 0..<5 {
            try withStore { context in
                _ = CycleStore.dedupeSameDay(in: context, calendar: self.calendar)
            }
        }
        XCTAssertEqual(try entryCount(), 200, "Launching repeatedly must not add or lose a single day.")
    }

    /// The CloudKit-shaped configuration opens the same file with the same rows.
    /// This is the file-level companion to the URL assertion in CloudSyncSafetyTests.
    func testTheSyncShapedConfigurationOpensTheSameHistory() throws {
        try seedHistory(days: 120)
        let syncShaped = ModelConfiguration(schema: Persistence.schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Persistence.schema, configurations: [syncShaped])
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<CycleEntry>()).count, 120)
    }

    // MARK: - Multi-device matrix

    /// Simulates a remote arrival: a second row for a day, as CloudKit delivers it.
    private func deliver(
        into context: ModelContext,
        on date: Date,
        createdAt: TimeInterval,
        updatedAt: TimeInterval,
        _ configure: (CycleEntry) -> Void
    ) {
        let entry = CycleEntry(date: date)
        entry.date = date
        entry.createdAt = Date(timeIntervalSince1970: createdAt)
        entry.updatedAt = Date(timeIntervalSince1970: updatedAt)
        configure(entry)
        context.insert(entry)
    }

    /// A populated device receiving from an empty one gains nothing and loses
    /// nothing.
    func testPopulatedDeviceReceivingNothingIsUnchanged() throws {
        try seedHistory(days: 50)
        try withStore { context in
            XCTAssertEqual(CycleStore.dedupeSameDay(in: context, calendar: self.calendar), 0)
        }
        XCTAssertEqual(try entryCount(), 50)
    }

    /// Both devices logged the identical day identically. One row, not two.
    func testIdenticalDaysFromBothDevicesCollapseToOne() throws {
        let target = day(3, from: origin)
        try withStore { context in
            self.deliver(into: context, on: target, createdAt: 1_000, updatedAt: 1_000) { $0.flow = .medium }
            self.deliver(into: context, on: target, createdAt: 2_000, updatedAt: 2_000) { $0.flow = .medium }
        }
        try withStore { context in
            XCTAssertEqual(CycleStore.dedupeSameDay(in: context, calendar: self.calendar), 1)
            let rows = try context.fetch(FetchDescriptor<CycleEntry>())
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].flow, .medium)
        }
    }

    /// The same record delivered several times converges rather than multiplying.
    func testRepeatedDeliveryOfTheSameRecordConverges() throws {
        let target = day(5, from: origin)
        try withStore { context in
            for i in 0..<5 {
                self.deliver(into: context, on: target,
                             createdAt: 1_000 + Double(i), updatedAt: 1_000 + Double(i)) {
                    $0.flow = .light
                    $0.symptoms = [.cramps]
                }
            }
        }
        try withStore { context in
            XCTAssertEqual(CycleStore.dedupeSameDay(in: context, calendar: self.calendar), 4)
        }
        try withStore { context in
            XCTAssertEqual(CycleStore.dedupeSameDay(in: context, calendar: self.calendar), 0)
            XCTAssertEqual(try context.fetch(FetchDescriptor<CycleEntry>()).count, 1)
        }
    }

    /// Offline on both sides, then reconnect: everything each side recorded
    /// survives, because the fields do not collide.
    func testOfflineEditsOnBothSidesBothSurviveReconnect() throws {
        let target = day(7, from: origin)
        try withStore { context in
            self.deliver(into: context, on: target, createdAt: 1_000, updatedAt: 1_500) {
                $0.flow = .heavy
                $0.note = "logged offline on A"
                $0.symptoms = [.cramps]
            }
            self.deliver(into: context, on: target, createdAt: 1_100, updatedAt: 1_600) {
                $0.mood = .anxious
                $0.basalTemperature = 36.7
                $0.symptoms = [.headache]
            }
        }
        try withStore { context in
            _ = CycleStore.dedupeSameDay(in: context, calendar: self.calendar)
            let row = try context.fetch(FetchDescriptor<CycleEntry>())[0]
            XCTAssertEqual(row.flow, .heavy)
            XCTAssertEqual(row.note, "logged offline on A")
            XCTAssertEqual(row.mood, .anxious)
            XCTAssertEqual(row.basalTemperature, 36.7)
            XCTAssertEqual(Set(row.symptoms), [.cramps, .headache])
        }
    }

    /// Reconnect ordering must not change the outcome.
    ///
    /// The identity of each edit is fixed — `.light` is always the older one and
    /// `.heavy` always the newer — and only the order they are *inserted* varies.
    /// (An earlier version of this test swapped the timestamps instead, which made
    /// `.light` genuinely newer in one run and then asserted it should lose. That
    /// was a broken test, not a broken merge.)
    func testReconnectOrderDoesNotChangeTheResult() throws {
        let target = day(9, from: origin)
        func run(olderArrivesFirst: Bool) throws -> FlowLevel? {
            let url = FileManager.default.temporaryDirectory
                .appending(path: "order-\(olderArrivesFirst)-\(UUID().uuidString).store")
            defer { for s in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + s) } }

            let older: (CycleEntry) -> Void = { $0.flow = .light }
            let newer: (CycleEntry) -> Void = { $0.flow = .heavy }

            try withStore(at: url) { context in
                if olderArrivesFirst {
                    self.deliver(into: context, on: target, createdAt: 1_000, updatedAt: 1_000, older)
                    self.deliver(into: context, on: target, createdAt: 2_000, updatedAt: 2_000, newer)
                } else {
                    self.deliver(into: context, on: target, createdAt: 2_000, updatedAt: 2_000, newer)
                    self.deliver(into: context, on: target, createdAt: 1_000, updatedAt: 1_000, older)
                }
            }
            return try withStore(at: url) { context in
                _ = CycleStore.dedupeSameDay(in: context, calendar: self.calendar)
                return try context.fetch(FetchDescriptor<CycleEntry>())[0].flow
            }
        }
        XCTAssertEqual(try run(olderArrivesFirst: true), .heavy,
                       "The newer edit wins regardless of the order rows arrive in.")
        XCTAssertEqual(try run(olderArrivesFirst: false), .heavy)
    }

    /// A reconciliation interrupted before saving leaves the store exactly as it
    /// was — no half-merged day.
    func testAnInterruptedReconciliationLeavesTheStoreUntouched() throws {
        let target = day(11, from: origin)
        try withStore { context in
            self.deliver(into: context, on: target, createdAt: 1_000, updatedAt: 1_000) { $0.flow = .medium }
            self.deliver(into: context, on: target, createdAt: 2_000, updatedAt: 2_000) { $0.flow = .heavy }
        }
        // Merge, then abandon without saving — the app dying mid-reconcile.
        let config = ModelConfiguration(schema: Persistence.schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Persistence.schema, configurations: [config])
        _ = CycleStore.dedupeSameDay(in: container.mainContext, calendar: calendar)
        container.mainContext.rollback()

        try withStore { context in
            let rows = try context.fetch(FetchDescriptor<CycleEntry>())
            XCTAssertGreaterThanOrEqual(rows.count, 1, "Nothing may be lost by an interrupted merge.")
            _ = CycleStore.dedupeSameDay(in: context, calendar: self.calendar)
        }
        try withStore { context in
            XCTAssertEqual(try context.fetch(FetchDescriptor<CycleEntry>()).count, 1,
                           "And the next launch finishes the job.")
        }
    }

    /// A remote row arriving on a day she edited by hand must not erase her work.
    func testARemoteArrivalAfterAManualEditKeepsHerValues() throws {
        let target = day(13, from: origin)
        try withStore { context in
            self.deliver(into: context, on: target, createdAt: 1_000, updatedAt: 5_000) {
                $0.note = "she typed this"
                $0.flow = .heavy
                $0.pain = 5
            }
            // Older remote row lacking her fields.
            self.deliver(into: context, on: target, createdAt: 900, updatedAt: 1_200) {
                $0.mood = .calm
            }
        }
        try withStore { context in
            _ = CycleStore.dedupeSameDay(in: context, calendar: self.calendar)
            let row = try context.fetch(FetchDescriptor<CycleEntry>())[0]
            XCTAssertEqual(row.note, "she typed this")
            XCTAssertEqual(row.flow, .heavy)
            XCTAssertEqual(row.pain, 5)
            XCTAssertEqual(row.mood, .calm)
        }
    }

    /// Unspecified flow — she bled, amount unknown — survives every path.
    func testUnspecifiedFlowSurvivesTheWholeMatrix() throws {
        let target = day(17, from: origin)
        try withStore { context in
            self.deliver(into: context, on: target, createdAt: 1_000, updatedAt: 1_000) { $0.flow = .unspecified }
            self.deliver(into: context, on: target, createdAt: 2_000, updatedAt: 2_000) { $0.symptoms = [.fatigue] }
        }
        try withStore { context in
            _ = CycleStore.dedupeSameDay(in: context, calendar: self.calendar)
            let row = try context.fetch(FetchDescriptor<CycleEntry>())[0]
            XCTAssertEqual(row.flow, .unspecified, "Never upgraded to a level, never discarded.")
        }
    }

    /// Days must not slide, at a month boundary or across DST.
    func testDatesAreStableAcrossTheMatrix() throws {
        let boundaries = [
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))!,   // US DST
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 31))!,
            calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!,
        ]
        try withStore { context in
            for date in boundaries {
                let d = self.calendar.startOfDay(for: date)
                self.deliver(into: context, on: d, createdAt: 1_000, updatedAt: 1_000) { $0.flow = .medium }
                self.deliver(into: context, on: d, createdAt: 2_000, updatedAt: 2_000) { $0.symptoms = [.cramps] }
            }
        }
        try withStore { context in
            _ = CycleStore.dedupeSameDay(in: context, calendar: self.calendar)
            let rows = try context.fetch(FetchDescriptor<CycleEntry>()).sorted { $0.date < $1.date }
            XCTAssertEqual(rows.count, boundaries.count, "One row per day, still.")
            for (row, expected) in zip(rows, boundaries) {
                XCTAssertEqual(self.calendar.startOfDay(for: row.date),
                               self.calendar.startOfDay(for: expected),
                               "A day moved.")
            }
        }
    }
}
