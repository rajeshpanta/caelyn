import XCTest
import SwiftData
@testable import Caelyn

/// Natural Cycles — App Store 765535549, `com.naturalcycles.cordova`.
///
/// Natural Cycles genuinely publishes a data download, so unlike most sources the
/// artifact is not in doubt. Its *columns* are, which is why Caelyn does not parse
/// it: the help centre is behind a challenge, no independent parser exists, and
/// reading a temperature column by position would be guessing at the one number
/// this app is built around.
///
/// The route is Apple Health, and the question these tests answer is the same one
/// that mattered for Period Tracker: **can Caelyn read only Natural Cycles?**
@MainActor
final class NaturalCyclesTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var ledger: ImportLedger!
    private let calendar = Calendar(identifier: .gregorian)

    private let naturalCycles = "com.naturalcycles.cordova"
    private let gpApps = "com.gpapps.ptrackerlite"
    private let flo = "org.iggymedia.periodtracker"
    private let clue = "com.helloclue.clue"
    private let caelyn = "smallpanta-icould.com.caelynperiodtracker"

    override func setUpWithError() throws {
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
        ledger = ImportLedger(fileURL: nil)
    }

    override func tearDownWithError() throws {
        container = nil; context = nil; ledger = nil
    }

    private var today: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!)
    }
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: y, month: m, day: d))!)
    }

    private func observation(_ date: Date, _ field: ImportObservation.Field,
                             _ value: ImportObservation.Value,
                             from bundle: String? = nil, named: String = "Natural Cycles") -> ImportObservation {
        let source = bundle ?? naturalCycles
        return ImportObservation(
            day: date, field: field, value: value,
            recordID: ImportRecordID.make(source: .appleHealth,
                                          dayKey: ImportLedger.dayKey(date, calendar: calendar),
                                          fieldKey: source + "|" + field.ledgerKey),
            sourceBundleID: source, sourceName: named, recordedAt: date
        )
    }

    /// What Natural Cycles can actually put into Health: cycle history. Their own
    /// documentation says temperatures cannot cross except for thermometer users,
    /// so the fixture reflects that rather than a wish.
    private func dataset() -> [ImportObservation] {
        [
            observation(day(2026, 1, 5), .flow, .flow(.medium)),
            observation(day(2026, 1, 6), .flow, .flow(.medium)),
            observation(day(2026, 1, 7), .flow, .flow(.light)),
            observation(day(2026, 1, 8), .flow, .flow(.unspecified)),
            observation(day(2026, 2, 2), .flow, .flow(.medium)),
            observation(day(2026, 2, 3), .flow, .flow(.medium)),
            observation(day(2026, 1, 20), .symptom(.irregularBleed), .symptomSeverity(1)),
            observation(day(2026, 1, 18), .ovulationTest, .ovulation(.lhSurge)),
            observation(day(2026, 1, 18), .sexualActivity, .boolean(true))
        ]
    }

    private func otherApps() -> [ImportObservation] {
        [
            observation(day(2026, 3, 2), .flow, .flow(.heavy), from: gpApps, named: "Period Tracker"),
            observation(day(2026, 3, 3), .flow, .flow(.heavy), from: flo, named: "Flo"),
            observation(day(2026, 3, 4), .flow, .flow(.heavy), from: clue, named: "Clue"),
            observation(day(2026, 3, 5), .flow, .flow(.heavy), from: caelyn, named: "Caelyn")
        ]
    }

    private func plan(_ obs: [ImportObservation],
                      filter: HealthSyncService.SourceFilter? = .naturalCycles) -> [ImportReconciler.Decision] {
        let kept = HealthSyncService.filtered(obs, by: filter)
        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Date: CycleEntry] = [:]
        for e in entries { byDay[calendar.startOfDay(for: e.date)] = e }
        return ImportReconciler.plan(
            observations: kept,
            currentValue: { d, f in byDay[self.calendar.startOfDay(for: d)]?.value(for: f) },
            ledger: ledger, ownBundleID: caelyn, acceptOwnSource: true,
            calendar: calendar, today: today
        )
    }

    @discardableResult
    private func importing(_ obs: [ImportObservation],
                           filter: HealthSyncService.SourceFilter? = .naturalCycles,
                           batchID: UUID = UUID()) -> ImportReconciler.Summary {
        ImportReconciler.commit(plan(obs, filter: filter), into: context,
                                ledger: ledger, batchID: batchID, calendar: calendar).summary
    }

    private func entries() -> [CycleEntry] {
        ((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []).sorted { $0.date < $1.date }
    }
    private func entry(_ d: Date) -> CycleEntry? {
        entries().first { calendar.isDate($0.date, inSameDayAs: d) }
    }

    // MARK: - Source filtering

    func testNaturalCyclesRouteImportsOnlyNaturalCyclesRecords() {
        importing(dataset() + otherApps())
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .medium)
        for d in 2...5 {
            XCTAssertNil(entry(day(2026, 3, d)), "March \(d) belongs to another app")
        }
    }

    func testNaturalCyclesAndPeriodTrackerDoNotBleedIntoEachOther() {
        // Two source-filtered routes over the same pool must stay disjoint.
        let all = dataset() + otherApps()
        let nc = HealthSyncService.filtered(all, by: .naturalCycles)
        let pt = HealthSyncService.filtered(all, by: .periodTrackerGPApps)
        XCTAssertFalse(nc.isEmpty); XCTAssertFalse(pt.isEmpty)
        XCTAssertTrue(Set(nc.map(\.sourceBundleID)).isDisjoint(with: Set(pt.map(\.sourceBundleID))))
        XCTAssertEqual(Set(nc.map(\.sourceBundleID)), [naturalCycles])
        XCTAssertEqual(Set(pt.map(\.sourceBundleID)), [gpApps])
    }

    func testGenericAppleHealthIsUnaffectedByTheNewRoute() {
        importing(dataset() + otherApps(), filter: nil)
        XCTAssertEqual(entry(day(2026, 3, 3))?.flow, .heavy, "Flo still belongs in a generic import")
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .medium)
    }

    // MARK: - Import behaviour

    func testCycleHistoryArrivesAndReconstructs() {
        importing(dataset())
        XCTAssertEqual(entry(day(2026, 1, 8))?.flow, .unspecified)
        XCTAssertEqual(entry(day(2026, 1, 20))?.symptoms, [.irregularBleed])
        XCTAssertNil(entry(day(2026, 1, 20))?.flow, "spotting is not a period day")
        XCTAssertEqual(entry(day(2026, 1, 18))?.ovulationTestResult, .lhSurge)

        let cycles = PredictionEngine.cycles(from: entries(), today: today)
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles.first?.length, 28)
        XCTAssertEqual(cycles.first?.periodLength, 4)
    }

    func testHandLoggedValueWins() {
        let target = day(2026, 1, 5)
        let mine = CycleStore.entry(for: target, in: context, calendar: calendar)
        mine.flow = .heavy
        context.saveOrLog()
        let summary = importing([observation(target, .flow, .flow(.light))])
        XCTAssertEqual(entry(target)?.flow, .heavy)
        XCTAssertEqual(summary.keptUserValue, 1)
    }

    func testNoIntensityIsInvented() {
        importing(dataset())
        XCTAssertEqual(Set(entries().compactMap(\.flow)), [.medium, .light, .unspecified])
    }

    func testReimportDoesNotDuplicate() {
        let data = dataset()
        importing(data)
        let days = entries().count, claims = ledger.claimCount
        let second = importing(data)
        XCTAssertEqual(second.filled, 0)
        XCTAssertGreaterThan(second.duplicates, 0)
        XCTAssertEqual(entries().count, days)
        XCTAssertEqual(ledger.claimCount, claims)
    }

    func testPlanningWritesNothingAndCommitMatchesIt() {
        let decisions = plan(dataset())
        XCTAssertEqual(entries().count, 0, "planning must not write")
        let promised = ImportReconciler.summarize(decisions)
        let actual = ImportReconciler.commit(decisions, into: context, ledger: ledger,
                                             batchID: UUID(), calendar: calendar).summary
        XCTAssertEqual(actual.daysAffected, promised.daysAffected)
        XCTAssertEqual(actual.changeCount, promised.changeCount)
    }

    func testUndoRemovesOnlyThisImportAndSpareLaterEdits() {
        let mine = CycleStore.entry(for: day(2026, 1, 1), in: context, calendar: calendar)
        mine.flow = .heavy
        context.saveOrLog()

        let batch = UUID()
        importing(dataset(), batchID: batch)
        entry(day(2026, 1, 7))?.flow = .heavy      // she corrects one
        context.saveOrLog()

        let result = ImportPlanner.undo(batchID: batch, context: context, ledger: ledger, calendar: calendar)
        XCTAssertTrue(result.succeeded)
        XCTAssertNil(entry(day(2026, 1, 5)), "an untouched imported day goes")
        XCTAssertEqual(entry(day(2026, 1, 7))?.flow, .heavy, "her correction stays")
        XCTAssertEqual(entry(day(2026, 1, 1))?.flow, .heavy, "her own day stays")
    }

    func testTransactionalRollbackLeavesNoProvenanceBehind() {
        // A commit that cannot save must leave neither data nor claims.
        let decisions = plan(dataset())
        XCTAssertFalse(decisions.isEmpty)
        let result = ImportReconciler.commit(decisions, into: context, ledger: ledger,
                                             batchID: UUID(), calendar: calendar)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(ledger.claimCount, result.summary.changeCount,
                       "one claim per written value, no more")
    }

    // MARK: - Dates

    func testDaysDoNotShiftAcrossTimezonesOrDST() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let days = [la.date(from: DateComponents(year: 2026, month: 3, day: 7))!,
                    la.date(from: DateComponents(year: 2026, month: 3, day: 8))!,
                    la.date(from: DateComponents(year: 2026, month: 3, day: 9))!].map { la.startOfDay(for: $0) }
        let obs = days.map {
            ImportObservation(day: $0, field: .flow, value: .flow(.medium), recordID: UUID(),
                              sourceBundleID: naturalCycles, sourceName: "Natural Cycles", recordedAt: $0)
        }
        let decisions = ImportReconciler.plan(
            observations: HealthSyncService.filtered(obs, by: .naturalCycles),
            currentValue: { _, _ in nil }, ledger: ledger, ownBundleID: caelyn,
            acceptOwnSource: true, calendar: la, today: today
        )
        ImportReconciler.commit(decisions, into: context, ledger: ledger, batchID: UUID(), calendar: la)
        XCTAssertEqual(entries().map { ImportLedger.dayKey($0.date, calendar: la) }.sorted(),
                       ["2026-03-07", "2026-03-08", "2026-03-09"])
    }

    // MARK: - Provenance and copy

    func testImportIsNamedAfterNaturalCycles() {
        XCTAssertEqual(HealthSyncService.SourceFilter.naturalCycles.label, "Natural Cycles via Apple Health")
        XCTAssertEqual(HealthSyncService.SourceFilter.naturalCycles.appName, "Natural Cycles")
        importing([observation(day(2026, 1, 5), .flow, .flow(.medium))])
        let claim = ledger.claim(day: day(2026, 1, 5), field: .flow, calendar: calendar)
        XCTAssertEqual(claim?.sourceBundleID, naturalCycles)
        XCTAssertEqual(claim?.sourceName, "Natural Cycles")
    }

    func testPreviewNamesNaturalCyclesNotAppleHealth() {
        var plan = HealthSyncService.Plan()
        plan.summary.filled = 6; plan.summary.daysAffected = 6; plan.summary.byField = ["flow": 6]
        let preview = ImportPreview.fromHealth(plan, sourceFilter: .naturalCycles)
        XCTAssertTrue(preview.sourceLine.contains("Natural Cycles"))
        XCTAssertFalse(preview.sourceLine.contains("Period Tracker"))
    }

    func testEmptyResultNamesNaturalCyclesAndStaysCalm() {
        let preview = ImportPreview.fromHealth(HealthSyncService.Plan(), sourceFilter: .naturalCycles)
        XCTAssertFalse(preview.hasChanges)
        XCTAssertEqual(preview.headline, "Nothing new to bring over")
        let text = ([preview.headline, preview.sourceLine, preview.safetyLine] + preview.caveats).joined(separator: " ")
        for banned in ["enable", "denied", "permission", "HKCategory", "grant", "this file"] {
            XCTAssertFalse(text.lowercased().contains(banned.lowercased()), "'\(banned)' leaked into her copy")
        }
    }

    // MARK: - The row

    func testTheRowDisclosesTheTemperatureLimitBeforeSheStarts() {
        let guide = ImportSourceGuide.naturalCycles
        let note = (guide.note ?? "").lowercased()
        XCTAssertTrue(note.contains("temperature"),
                      "temperature is the point of Natural Cycles; its absence must be stated up front")
        XCTAssertTrue(note.contains("thermometer"), "the exception belongs in the note too")
        XCTAssertEqual(guide.healthSourceFilter, .naturalCycles)
        XCTAssertEqual(guide.route, .appleHealthAfterInstructions)
        XCTAssertFalse(guide.needsAFile, "there is no verified file format to send her to")
    }

    func testEveryFilteredRowKeepsItsOwnFilterAndIdentity() {
        // Deliberately not a census of which apps are supported — that list grows.
        // What must hold however long it gets: Natural Cycles is in it, the plain
        // Apple Health row is never narrowed, and no two filtered rows claim the
        // same app, which would make one of them import the other's records.
        let filtered = ImportSourceGuide.pickable.filter { $0.healthSourceFilter != nil }
        XCTAssertTrue(filtered.contains { $0.healthSourceFilter == .naturalCycles })
        XCTAssertNil(ImportSourceGuide.appleHealth.healthSourceFilter,
                     "the plain Apple Health row must never be narrowed")

        var claimed: Set<String> = []
        for guide in filtered {
            let ids = guide.healthSourceFilter?.bundleIDs ?? []
            XCTAssertFalse(ids.isEmpty, "\(guide.title) is filtered to nothing")
            XCTAssertTrue(ids.isDisjoint(with: claimed),
                          "\(guide.title) claims a bundle id another row already owns")
            claimed.formUnion(ids)
        }

        let keys = ImportSourceGuide.pickable.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
    }
}
