import XCTest
import SwiftData
@testable import Caelyn

/// The day a logged entry belongs to must not change when she changes timezone.
///
/// **What this protects.** An entry used to store the *instant* of local midnight
/// and every reader worked out the day by truncating it again at read time. Those
/// are different questions: midnight on 1 June in Tokyo is 15:00 UTC on 31 May, so
/// in New York that instant falls on the thirty-first. A period logged on the first
/// read as starting on the thirty-first the moment she landed, and her cycle day,
/// prediction, calendar colours and widget all moved with it. Editing that day then
/// created a second row, and the launch dedupe could not repair it because in New
/// York the two rows really were different days — it healed only when she flew home.
///
/// `CycleEntry.dayKey` now stores the day instead of inferring it. These tests are
/// the reason it exists.
@MainActor
final class CivilDayTests: XCTestCase {

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

    private func travel(to id: String) { NSTimeZone.default = TimeZone(identifier: id)! }
    private func localDay(_ y: Int, _ m: Int, _ d: Int) -> Date {
        let cal = Calendar.current
        return cal.startOfDay(for: cal.date(from: DateComponents(year: y, month: m, day: d))!)
    }
    private func allEntries() -> [CycleEntry] {
        (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
    }
    private func logPeriod(startingOn start: Date, days: Int = 5) {
        let cal = Calendar.current
        for i in 0..<days {
            let e = CycleStore.entry(for: cal.date(byAdding: .day, value: i, to: start)!, in: context)
            e.flow = .medium
        }
        context.saveOrLog()
    }

    // MARK: - CivilDay itself

    func testAKeyNamesTheSameDayInEveryTimezone() {
        travel(to: "Asia/Tokyo")
        let key = CivilDay.key(for: localDay(2026, 6, 1))
        XCTAssertEqual(key, 20260601)

        for zone in ["America/New_York", "America/Los_Angeles", "Europe/Berlin",
                     "Pacific/Kiritimati", "Pacific/Midway", "Asia/Kathmandu", "UTC"] {
            travel(to: zone)
            let back = CivilDay.localDate(for: key)
            XCTAssertEqual(CivilDay.key(for: back), key, "round trip broke in \(zone)")
            let c = Calendar.current.dateComponents([.year, .month, .day], from: back)
            XCTAssertEqual([c.year, c.month, c.day], [2026, 6, 1], "wrong day in \(zone)")
        }
    }

    func testDayArithmeticIsExactAcrossDaylightSavingAndYearEnds() {
        travel(to: "America/New_York")       // forward 8 Mar, back 1 Nov 2026
        XCTAssertEqual(CivilDay.days(from: 20260301, to: 20260315), 14, "spring forward moved a gap")
        XCTAssertEqual(CivilDay.days(from: 20261025, to: 20261108), 14, "fall back moved a gap")
        XCTAssertEqual(CivilDay.days(from: 20261231, to: 20270101), 1, "year boundary")
        XCTAssertEqual(CivilDay.key(20260228, offsetBy: 1), 20260301, "non-leap February")
        XCTAssertEqual(CivilDay.key(20240228, offsetBy: 1), 20240229, "leap day")

        // Brazil used to begin daylight saving at 00:00, so that local midnight
        // does not exist at all.
        travel(to: "America/Sao_Paulo")
        XCTAssertEqual(CivilDay.days(from: 20181014, to: 20181015), 1, "midnight-skip day")
        XCTAssertNotEqual(CivilDay.localDate(for: 20181015), .distantPast, "midnight-skip day failed to resolve")
    }

    /// A row written before `dayKey` existed resolves to nothing rather than to
    /// some arbitrary day, so a missed backfill is loud instead of silent.
    func testAZeroKeyDoesNotPretendToBeADay() {
        XCTAssertEqual(CivilDay.localDate(for: 0), .distantPast)
    }

    // MARK: - What she actually experiences

    func testHerPeriodStaysOnTheDaySheLoggedItAfterFlyingWest() {
        travel(to: "Asia/Tokyo")
        logPeriod(startingOn: localDay(2026, 6, 1))
        let home = CycleModel.make(entries: allEntries(), profile: nil, today: localDay(2026, 6, 10))
        XCTAssertEqual(Calendar.current.component(.day, from: home.anchor!), 1, "sanity: the 1st in Tokyo")

        travel(to: "America/New_York")
        let away = CycleModel.make(entries: allEntries(), profile: nil, today: localDay(2026, 6, 10))
        XCTAssertEqual(Calendar.current.component(.day, from: away.anchor!), 1,
            "after Tokyo → New York her period start moved")
        XCTAssertEqual(home.cycleDay, away.cycleDay, "her cycle day moved with it")
    }

    func testTheSameHoldsForTheWidestTripOnEarth() {
        travel(to: "Pacific/Kiritimati")     // UTC+14
        logPeriod(startingOn: localDay(2026, 6, 1))
        travel(to: "Pacific/Midway")         // UTC-11, 26 hours away
        let model = CycleModel.make(entries: allEntries(), profile: nil, today: localDay(2026, 6, 10))
        XCTAssertEqual(Calendar.current.component(.day, from: model.anchor!), 1)
    }

    func testEditingADayAfterTravelDoesNotCreateASecondRow() {
        travel(to: "Asia/Tokyo")
        let e = CycleStore.entry(for: localDay(2026, 6, 1), in: context)
        e.flow = .medium
        context.saveOrLog()
        XCTAssertEqual(allEntries().count, 1)

        travel(to: "America/New_York")
        let again = CycleStore.entry(for: localDay(2026, 6, 1), in: context)
        again.symptoms = [.cramps]
        context.saveOrLog()

        XCTAssertEqual(allEntries().count, 1, "the same calendar day was split into two rows")
        XCTAssertEqual(allEntries().first?.flow, .medium, "and the original log must still be on it")
        XCTAssertEqual(allEntries().first?.symptoms, [.cramps])
    }

    func testTheCalendarPaintsTheDaySheLoggedAfterTravel() {
        travel(to: "Asia/Tokyo")
        logPeriod(startingOn: localDay(2026, 6, 1), days: 3)
        travel(to: "America/Los_Angeles")

        let entries = allEntries()
        let today = localDay(2026, 6, 10)
        let model = CycleModel.make(entries: entries, profile: nil, today: today)
        let state = CalendarMath.dayState(for: localDay(2026, 6, 1), month: localDay(2026, 6, 1),
                                          entries: entries, cycle: model, today: today)
        XCTAssertEqual(state.marker, .loggedPeriod(.medium),
            "the grid lost the flow she logged on this day")
    }

    func testFlyingEastIsStillFine() {
        travel(to: "America/Los_Angeles")
        logPeriod(startingOn: localDay(2026, 6, 1))
        travel(to: "Europe/Berlin")
        let model = CycleModel.make(entries: allEntries(), profile: nil, today: localDay(2026, 6, 10))
        XCTAssertEqual(Calendar.current.component(.day, from: model.anchor!), 1)
    }

    // MARK: - Upgrading an existing install

    /// Rows written before `dayKey` existed carry 0. The launch pass keys them to
    /// the day they currently display as, so nobody's history visibly moves.
    func testTheLaunchPassBackfillsOldRowsToTheDayTheyAlreadyShow() {
        travel(to: "Europe/Berlin")
        let cal = Calendar.current
        for i in 0..<5 {
            let e = CycleEntry(date: cal.date(byAdding: .day, value: i, to: localDay(2026, 6, 1))!)
            e.flow = .medium
            e.dayKey = 0                    // as a pre-upgrade row would be
            context.insert(e)
        }
        context.saveOrLog()
        XCTAssertEqual(allEntries().filter { $0.dayKey == 0 }.count, 5, "precondition")

        CycleStore.dedupeSameDay(in: context)

        XCTAssertTrue(allEntries().allSatisfy { $0.dayKey != 0 }, "a row was left unkeyed")
        XCTAssertEqual(Set(allEntries().map(\.dayKey)),
                       [20260601, 20260602, 20260603, 20260604, 20260605],
                       "a row was keyed to a different day than it displayed as")
        XCTAssertEqual(allEntries().count, 5, "the backfill must not merge distinct days")
    }

    func testTheBackfillIsIdempotent() {
        travel(to: "UTC")
        logPeriod(startingOn: localDay(2026, 6, 1))
        let before = allEntries().map(\.dayKey).sorted()
        CycleStore.dedupeSameDay(in: context)
        CycleStore.dedupeSameDay(in: context)
        XCTAssertEqual(allEntries().map(\.dayKey).sorted(), before)
        XCTAssertEqual(allEntries().count, 5)
    }

    /// Two rows that a pre-upgrade store split across a timezone move are merged
    /// once they are keyed, rather than staying split forever.
    func testTwoRowsForOneDayAreMergedOnceTheyAreKeyed() {
        travel(to: "Europe/Berlin")
        let a = CycleEntry(date: localDay(2026, 6, 1)); a.flow = .light; a.dayKey = 0
        a.createdAt = Date(timeIntervalSince1970: 1); a.updatedAt = Date(timeIntervalSince1970: 1)
        let b = CycleEntry(date: localDay(2026, 6, 1)); b.pain = 6; b.dayKey = 0
        b.createdAt = Date(timeIntervalSince1970: 2); b.updatedAt = Date(timeIntervalSince1970: 2)
        context.insert(a); context.insert(b)
        context.saveOrLog()

        let removed = CycleStore.dedupeSameDay(in: context)
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(allEntries().count, 1)
        XCTAssertEqual(allEntries().first?.flow, .light)
        XCTAssertEqual(allEntries().first?.pain, 6)
    }

    // MARK: - The merge rule

    /// The union is deliberate, so this pins it rather than the opposite.
    /// Cramps on the phone plus bloating on the iPad means she had both.
    func testAMergeStaysAdditiveAcrossDevices() {
        travel(to: "UTC")
        let phone = CycleEntry(date: localDay(2026, 6, 1))
        phone.symptoms = [.cramps]; phone.painTypes = [.cramps]
        phone.createdAt = Date(timeIntervalSince1970: 1); phone.updatedAt = Date(timeIntervalSince1970: 1)
        let pad = CycleEntry(date: localDay(2026, 6, 1))
        pad.symptoms = [.bloating]; pad.painTypes = [.backPain]
        pad.createdAt = Date(timeIntervalSince1970: 2); pad.updatedAt = Date(timeIntervalSince1970: 2)
        context.insert(phone); context.insert(pad)
        context.saveOrLog()

        CycleStore.dedupeSameDay(in: context)
        let merged = allEntries()[0]
        XCTAssertEqual(Set(merged.symptoms), [.cramps, .bloating],
            "a symptom logged on one device was lost when the other merged in")
        XCTAssertEqual(Set(merged.painTypes), [.cramps, .backPain])
    }

    /// A newer but emptier row arriving from elsewhere must not blank anything.
    func testANewerEmptierRowCannotEraseWhatThisDeviceHolds() {
        travel(to: "UTC")
        let mine = CycleEntry(date: localDay(2026, 6, 1))
        mine.flow = .heavy; mine.note = "rough day"; mine.pain = 7
        mine.createdAt = Date(timeIntervalSince1970: 1); mine.updatedAt = Date(timeIntervalSince1970: 1)
        let incoming = CycleEntry(date: localDay(2026, 6, 1))
        incoming.mood = .tired
        incoming.createdAt = Date(timeIntervalSince1970: 2); incoming.updatedAt = Date(timeIntervalSince1970: 9_000)
        context.insert(mine); context.insert(incoming)
        context.saveOrLog()

        CycleStore.dedupeSameDay(in: context)
        let merged = allEntries()[0]
        XCTAssertEqual(merged.flow, .heavy)
        XCTAssertEqual(merged.note, "rough day")
        XCTAssertEqual(merged.pain, 7)
        XCTAssertEqual(merged.mood, .tired, "and what did arrive is kept")
    }

    func testAMergeNeverKeepsASeverityWithoutItsSymptom() {
        travel(to: "UTC")
        let old = CycleEntry(date: localDay(2026, 6, 1))
        old.symptoms = [.cramps]; old.symptomSeverity = ["cramps": 1]
        old.createdAt = Date(timeIntervalSince1970: 1); old.updatedAt = Date(timeIntervalSince1970: 1)
        let new = CycleEntry(date: localDay(2026, 6, 1))
        new.symptoms = []; new.symptomSeverity = ["bloating": 3]   // orphaned severity
        new.createdAt = Date(timeIntervalSince1970: 2); new.updatedAt = Date(timeIntervalSince1970: 2)
        context.insert(old); context.insert(new)
        context.saveOrLog()

        CycleStore.dedupeSameDay(in: context)
        let merged = allEntries()[0]
        let orphans = merged.symptomSeverity.keys.filter { key in
            !key.hasPrefix("custom:") && !merged.symptoms.contains { $0.rawValue == key }
        }
        XCTAssertTrue(orphans.isEmpty, "merged row carries severities for symptoms it does not have: \(orphans)")
    }

    // MARK: - Every write path keys its entry

    func testEveryWritePathLeavesAKeyedEntry() {
        travel(to: "Asia/Kathmandu")                    // UTC+5:45, a half-hour zone
        _ = CycleStore.entry(for: localDay(2026, 6, 1), in: context)
        let direct = CycleEntry(date: localDay(2026, 6, 2)); context.insert(direct)
        context.saveOrLog()

        for e in allEntries() {
            XCTAssertNotEqual(e.dayKey, 0, "an entry was written without a day key")
            XCTAssertEqual(CivilDay.key(for: e.day), e.dayKey, "key and day disagree")
        }
    }
}

/// The small Pass-D fixes, each of which was a thing Caelyn said that was not true.
@MainActor
final class CaelynSaysOnlyWhatItKnowsTests: XCTestCase {

    /// Home's ovulation headline is "Estimated ovulation window". The hint sits
    /// directly beneath it, and for anyone without a completed cycle there is no
    /// personalised line to replace it — so the same sentence appeared twice.
    func testTheOvulationHintDoesNotRepeatTheHomeHeadline() {
        let headline = HomeCopy.phaseHeadline(.ovulation, cycleDay: 14, daysUntilPeriod: 14)
        let hint = CyclePhase.ovulation.hint
        func normalised(_ s: String) -> String {
            s.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        }
        XCTAssertNotEqual(normalised(headline), normalised(hint),
            "Home stacks the same sentence twice during ovulation")
        XCTAssertFalse(hint.isEmpty)
    }

    /// Every phase hint should be worth the line it occupies.
    func testNoPhaseHintEchoesItsOwnHeadline() {
        for phase in CyclePhase.allCases where phase != .unknown {
            let headline = HomeCopy.phaseHeadline(phase, cycleDay: 10, daysUntilPeriod: 7)
            let hint = phase.hint
            XCTAssertNotEqual(headline.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " .")),
                              hint.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " .")),
                              "\(phase) says the same thing twice")
        }
    }

    /// With nothing logged and nothing stated, there is no cycle day to show.
    func testThereIsNoCycleDayToShowWithoutAnAnchor() {
        let model = CycleModel.make(entries: [], profile: nil, today: Date())
        XCTAssertFalse(model.hasPrediction,
            "the Log tab's header keys off this; if it is ever true with no anchor it will print `Cycle day 1`")
    }
}

/// Nothing may go back to working out an entry's day from its instant.
///
/// This is a source audit rather than a behavioural test because the failure it
/// guards against is invisible until someone changes timezone: the code compiles,
/// the tests pass at home, and the bug only appears on holiday. Nine sites were
/// still doing it after the first sweep of the obvious ones — a shell grep had
/// silently eaten the `$0` in its pattern — so this checks the source directly.
@MainActor
final class EntryDayDerivationAuditTests: XCTestCase {

    func testNoEntryLookupInfersTheDayFromItsInstant() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // CaelynTests
            .deletingLastPathComponent()      // repo root
            .appending(path: "Caelyn")
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("source tree not reachable from this host")
        }

        var offenders: [String] = []
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            for (i, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = String(rawLine)
                guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("//"),
                      !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") else { continue }
                let infersFromInstant =
                    (line.contains("inSameDayAs:") && line.contains(".date"))
                    || line.contains("startOfDay(for: entry.date)")
                    || line.contains("startOfDay(for: $0.date)")
                if infersFromInstant {
                    offenders.append("\(url.lastPathComponent):\(i + 1)")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "these work out an entry's day from its stored instant, which drifts the moment she changes timezone — use `entry.dayKey` or `CivilDay.localDate(for:)`: \(offenders)")
    }
}
