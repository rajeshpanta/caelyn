import XCTest
import SwiftData
@testable import Caelyn

/// A logged day must mean the same thing on every phone, in every time zone, under
/// every calendar iOS offers — and the one launch that upgrades her from 1.3 must
/// not get to decide otherwise.
///
/// **What these protect.** `dayKey` was introduced to stop a day drifting when she
/// travels, and it does. But it was minted with `Calendar.current`, which is not
/// only a time zone: it is also a *calendar system*. On an iPhone set to the Thai
/// Buddhist calendar — Settings → General → Language & Region, no jailbreak — the
/// year component of 2026 is 2569, so every entry was filed under key 25690305
/// instead of 20260305. It round-trips on her own phone, because the same wrong
/// calendar decodes it, and is meaningless anywhere else: on a second device, in an
/// export, or the moment she changes the setting.
///
/// Separately, the launch that backfills keys for a 1.3 user derived them from
/// wherever she happened to be standing that morning, and overwrote the original
/// timestamps in the same pass — so a wrong guess could not afterwards be told from
/// a right one, or undone.
@MainActor
final class DayIdentityTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var originalZone: TimeZone!

    override func setUpWithError() throws {
        originalZone = NSTimeZone.default
        container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        context = container.mainContext
    }
    override func tearDownWithError() throws {
        NSTimeZone.default = originalZone
        container = nil; context = nil
    }

    private func travel(_ id: String) { NSTimeZone.default = TimeZone(identifier: id)! }
    private func rows() -> [CycleEntry] { (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? [] }

    /// A Gregorian calendar in a named zone, for building fixtures.
    private func cal(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    // MARK: - The key must not carry the device's calendar system

    func testTheKeyIsTheSameNumberUnderEveryCalendarSystem() {
        let instant = cal("Europe/London")
            .date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 12))!

        var expected: Int?
        for identifier in [Calendar.Identifier.gregorian, .buddhist, .japanese,
                           .hebrew, .islamicUmmAlQura, .persian, .coptic, .republicOfChina] {
            var c = Calendar(identifier: identifier)
            c.timeZone = TimeZone(identifier: "Europe/London")!
            let key = CivilDay.key(for: instant, calendar: c)
            if expected == nil { expected = key }
            XCTAssertEqual(key, expected,
                "\(identifier) produced a different day key for the same instant — the key carries the device's calendar system, so her history is filed under a year no other device agrees with")
        }
        XCTAssertEqual(expected, 20260305, "the key should be the Gregorian civil date")
    }

    func testAKeyWrittenOnABuddhistCalendarPhoneIsReadableOnAGregorianOne() throws {
        var thai = Calendar(identifier: .buddhist)
        thai.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        let instant = thai.date(from: DateComponents(year: 2569, month: 3, day: 5, hour: 9))!

        let written = CivilDay.key(for: instant, calendar: thai)
        let readBack = try XCTUnwrap(CivilDay.localDate(for: written, calendar: cal("Asia/Bangkok")))
        let comps = cal("Asia/Bangkok").dateComponents([.year, .month, .day], from: readBack)
        XCTAssertEqual([comps.year, comps.month, comps.day], [2026, 3, 5],
            "a day logged on a Thai-calendar phone does not resolve to the same day on any other phone")
    }

    func testDayArithmeticDoesNotDependOnTheCalendarSystem() {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual(CivilDay.key(20260228, offsetBy: 1, calendar: japanese), 20260301)
        XCTAssertEqual(CivilDay.key(20240228, offsetBy: 1, calendar: japanese), 20240229, "leap day")
        XCTAssertEqual(CivilDay.days(from: 20260301, to: 20260315, calendar: japanese), 14)
    }

    /// The export already pins Gregorian when writing; the reader must match, or
    /// Caelyn rejects its own backup.
    func testCaelynsOwnExportReImportsOnANonGregorianPhone() throws {
        var thai = Calendar(identifier: .buddhist)
        thai.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        let day = try XCTUnwrap(ImportValues.day(from: "2026-03-05", using: nil, calendar: thai))
        let comps = cal("Asia/Bangkok").dateComponents([.year, .month, .day], from: day)
        XCTAssertEqual([comps.year, comps.month, comps.day], [2026, 3, 5],
            "an ISO date Caelyn itself wrote is read as a different day on a Thai-calendar phone")
    }

    // MARK: - Upgrading from 1.3

    /// Every 1.3 write path stored local midnight in the zone that wrote it, so the
    /// instant itself says which day she meant. The backfill must read that, not ask
    /// where she is standing this morning.
    func testTheUpgradeKeysHerHistoryToTheDaySheLoggedNotToWhereSheIsStanding() {
        // She logged a period in Tokyo on 1-5 June, on 1.3 (no dayKey).
        let tokyo = cal("Asia/Tokyo")
        let june1 = tokyo.startOfDay(for: tokyo.date(from: DateComponents(year: 2026, month: 6, day: 1))!)
        for i in 0..<5 {
            let e = CycleEntry(date: june1)
            e.date = tokyo.date(byAdding: .day, value: i, to: june1)!   // 1.3 stored local midnight
            e.dayKey = 0                                                // 1.3 had no key
            e.flow = .medium
            context.insert(e)
        }
        context.saveOrLog()

        // She happens to be in New York the morning she installs the update.
        travel("America/New_York")
        CycleStore.dedupeSameDay(in: context)

        XCTAssertEqual(rows().count, 5, "the upgrade merged days that were distinct")
        XCTAssertEqual(Set(rows().map(\.dayKey)),
                       [20260601, 20260602, 20260603, 20260604, 20260605],
                       "her Tokyo history was re-dated to the time zone she happened to be in when she updated")
    }

    func testTheUpgradeIsStableWhereverSheHappensToBe() {
        let berlin = cal("Europe/Berlin")
        let start = berlin.startOfDay(for: berlin.date(from: DateComponents(year: 2026, month: 6, day: 1))!)
        for i in 0..<3 {
            let e = CycleEntry(date: start)
            e.date = berlin.date(byAdding: .day, value: i, to: start)!
            e.dayKey = 0
            context.insert(e)
        }
        context.saveOrLog()

        travel("Pacific/Midway")                 // UTC-11, the worst case
        CycleStore.dedupeSameDay(in: context)
        XCTAssertEqual(Set(rows().map(\.dayKey)), [20260601, 20260602, 20260603])
    }

    /// The pass must not broadcast this device's idea of midnight onto a row another
    /// device wrote — on a synced store that is a change every other device then has
    /// to accept, and it destroys the only evidence of the original day.
    func testTheLaunchPassNeverRewritesTheStoredInstant() {
        let tokyo = cal("Asia/Tokyo")
        let june1 = tokyo.startOfDay(for: tokyo.date(from: DateComponents(year: 2026, month: 6, day: 1))!)
        let e = CycleStore.entry(for: june1, in: context, calendar: tokyo)
        e.flow = .medium
        context.saveOrLog()
        let storedInstant = e.date
        let storedKey = e.dayKey

        travel("America/Los_Angeles")
        CycleStore.dedupeSameDay(in: context)

        XCTAssertEqual(rows().first?.date, storedInstant,
            "the launch pass rewrote the stored timestamp from this device's calendar — on a synced store that is broadcast to every other device, and it erases the evidence of which day she meant")
        XCTAssertEqual(rows().first?.dayKey, storedKey, "and the day identity must not move either")
    }

    /// Running the pass twice, the second time somewhere else, must change nothing.
    func testTheLaunchPassIsAFixedPointAcrossTimeZones() {
        travel("Europe/London")
        for i in 0..<6 {
            let cal = Calendar.current
            let e = CycleStore.entry(for: cal.date(byAdding: .day, value: i,
                to: cal.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000)))!, in: context)
            e.flow = .medium
        }
        context.saveOrLog()
        CycleStore.dedupeSameDay(in: context)
        let before = rows().map { [String($0.dayKey), String($0.date.timeIntervalSince1970)] }.sorted { $0[0] < $1[0] }

        for zone in ["Asia/Tokyo", "America/Los_Angeles", "Pacific/Kiritimati", "UTC"] {
            travel(zone)
            CycleStore.dedupeSameDay(in: context)
            let after = rows().map { [String($0.dayKey), String($0.date.timeIntervalSince1970)] }.sorted { $0[0] < $1[0] }
            XCTAssertEqual(after, before, "running the launch pass in \(zone) changed stored data")
        }
    }

    /// A row keyed under the old calendar-dependent code must be repaired, not frozen.
    func testAnImpossibleKeyFromTheOldCodeIsRepairedFromTheStoredInstant() {
        let bangkok = cal("Asia/Bangkok")
        let day = bangkok.startOfDay(for: bangkok.date(from: DateComponents(year: 2026, month: 3, day: 5))!)
        let e = CycleEntry(date: day)
        e.date = day
        e.dayKey = 25690305          // what a Thai-calendar phone wrote
        e.flow = .medium
        context.insert(e)
        context.saveOrLog()

        travel("Asia/Bangkok")
        CycleStore.dedupeSameDay(in: context)
        XCTAssertEqual(rows().first?.dayKey, 20260305,
            "a key written under the device's own calendar system was left in place, so this row is filed 543 years away from every other device")
    }

    // MARK: - Nothing may read an unkeyed row as a real day

    /// On the first launch after upgrading, every row is briefly unkeyed. The widget
    /// and the Watch read the store in that window.
    func testAnUnkeyedRowReadsAsTheDayItHasAlwaysRead() {
        travel("Europe/London")
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))
        let e = CycleEntry(date: day)
        e.date = day
        e.dayKey = 0
        e.flow = .medium
        context.insert(e)
        context.saveOrLog()

        XCTAssertEqual(e.day, day,
            "an entry that has not been keyed yet resolves to the year 1 rather than to the day it has always displayed as — the widget and the Watch read the store in exactly that window and render a nonsense cycle day")
    }

    func testAnUnkeyedRowCannotAnchorAPrediction() {
        travel("Europe/London")
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))
        for i in 0..<5 {
            let e = CycleEntry(date: today)
            e.date = cal.date(byAdding: .day, value: i - 10, to: today)!
            e.dayKey = 0
            e.flow = .medium
            context.insert(e)
        }
        context.saveOrLog()

        let model = CycleModel.make(entries: rows(), profile: nil, today: today)
        let anchor = try? XCTUnwrap(model.anchor)
        XCTAssertNotNil(anchor)
        XCTAssertGreaterThan(anchor ?? .distantPast, cal.date(byAdding: .year, value: -1, to: today)!,
            "an unkeyed row anchored the prediction to the year 1, which every reader then treats as a real date")
    }
}

/// Every persisted day string must mean the same day on every phone.
///
/// The import ledger records which fields Caelyn has already claimed, keyed by
/// day, in a file that outlives any Settings change. Those keys were built from
/// the device's calendar system, so the same day stringified as `"2569-03-05"` on
/// a Thai-calendar phone: nothing already in the ledger matched, every
/// previously-imported field looked unclaimed, and a re-import would have
/// duplicated her whole history.
///
/// Behavioural rather than a source audit because the invariant is about the
/// values, not about how any one line is written.
@MainActor
final class PersistedDayStringTests: XCTestCase {

    private static let systems: [Calendar.Identifier] = [
        .gregorian, .buddhist, .japanese, .hebrew, .islamicUmmAlQura,
        .persian, .coptic, .republicOfChina, .indian, .chinese,
    ]

    private func calendars(in zone: String) -> [(Calendar.Identifier, Calendar)] {
        Self.systems.map { id in
            var c = Calendar(identifier: id)
            c.timeZone = TimeZone(identifier: zone)!
            return (id, c)
        }
    }

    func testTheLedgerDayKeyIsTheSameStringUnderEveryCalendarSystem() {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        let instant = gregorian.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 9))!

        for (id, cal) in calendars(in: "Asia/Bangkok") {
            XCTAssertEqual(ImportLedger.dayKey(instant, calendar: cal), "2026-03-05",
                "\(id) writes a different ledger key, so every claim already on disk stops matching and her history re-imports")
        }
    }

    func testAnISODayParsesToTheSameDayUnderEveryCalendarSystem() throws {
        for (id, cal) in calendars(in: "Europe/London") {
            let parsed = try XCTUnwrap(ImportValues.day(from: "2026-03-05", using: nil, calendar: cal),
                                       "\(id) failed to parse an ISO day at all")
            XCTAssertEqual(ImportLedger.dayKey(parsed, calendar: cal), "2026-03-05",
                "\(id) parses Caelyn's own export as a different day")
        }
    }

    func testTheLedgerRoundTripsItsOwnKeysUnderEveryCalendarSystem() throws {
        for (id, cal) in calendars(in: "Pacific/Auckland") {
            let day = try XCTUnwrap(ImportValues.day(from: "2026-03-05", using: nil, calendar: cal))
            XCTAssertEqual(CivilDay.key(for: day, calendar: cal), 20260305,
                "\(id): an imported day and a logged day disagree, so the import writes a second row for a day she already has")
        }
    }
}
