import XCTest
import SwiftData
@testable import Caelyn

/// Eve by Glow — App Store 1002275138, `com.glowing.lexie`.
///
/// Eve is the one source whose vendor names the reproductive HealthKit types
/// itself. Its App Store listing: *"Compatible with the Health App for tracking
/// Sleep, Steps, … and of course, menstrual health (Menstruation, Sexual Activity,
/// Spotting)."* All three are types Caelyn reads — so unlike every other bridge,
/// what should arrive is documented rather than assumed.
///
/// What the list omits matters just as much. Eve tracks moods, symptoms and BBT and
/// charts them, and none of those appear in its Health compatibility. The tests
/// below pin both halves: the three types arrive, and Eve is kept strictly apart
/// from Glow, its sibling app with a different bundle identifier.
@MainActor
final class GlowEveTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var ledger: ImportLedger!
    private let calendar = Calendar(identifier: .gregorian)

    private let eve = "com.glowing.lexie"
    private let glow = "com.upwlabs.emma"
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
    override func tearDownWithError() throws { container = nil; context = nil; ledger = nil }

    private var today: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!)
    }
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: y, month: m, day: d))!)
    }

    private func observation(_ date: Date, _ field: ImportObservation.Field,
                             _ value: ImportObservation.Value,
                             from bundle: String? = nil, named: String = "Eve") -> ImportObservation {
        let source = bundle ?? eve
        return ImportObservation(
            day: date, field: field, value: value,
            recordID: ImportRecordID.make(source: .appleHealth,
                                          dayKey: ImportLedger.dayKey(date, calendar: calendar),
                                          fieldKey: source + "|" + field.ledgerKey),
            sourceBundleID: source, sourceName: named, recordedAt: date
        )
    }

    /// Exactly what Eve's listing says it shares — menstruation, sexual activity
    /// and spotting — and nothing it doesn't.
    private func dataset() -> [ImportObservation] {
        [
            observation(day(2026, 1, 5), .flow, .flow(.heavy)),
            observation(day(2026, 1, 6), .flow, .flow(.medium)),
            observation(day(2026, 1, 7), .flow, .flow(.light)),
            observation(day(2026, 1, 8), .flow, .flow(.unspecified)),
            observation(day(2026, 2, 2), .flow, .flow(.medium)),
            observation(day(2026, 2, 3), .flow, .flow(.medium)),
            observation(day(2026, 1, 20), .symptom(.irregularBleed), .symptomSeverity(1)),
            observation(day(2026, 1, 14), .sexualActivity, .boolean(true)),
            observation(day(2026, 1, 18), .sexualActivity, .boolean(true))
        ]
    }

    private func otherApps() -> [ImportObservation] {
        [
            observation(day(2026, 3, 1), .flow, .flow(.heavy), from: glow, named: "Glow"),
            observation(day(2026, 3, 2), .flow, .flow(.heavy), from: naturalCycles, named: "Natural Cycles"),
            observation(day(2026, 3, 3), .flow, .flow(.heavy), from: gpApps, named: "Period Tracker"),
            observation(day(2026, 3, 4), .flow, .flow(.heavy), from: flo, named: "Flo"),
            observation(day(2026, 3, 5), .flow, .flow(.heavy), from: clue, named: "Clue"),
            observation(day(2026, 3, 6), .flow, .flow(.heavy), from: caelyn, named: "Caelyn")
        ]
    }

    private func plan(_ obs: [ImportObservation],
                      filter: HealthSyncService.SourceFilter? = .glowEve) -> [ImportReconciler.Decision] {
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
                           filter: HealthSyncService.SourceFilter? = .glowEve,
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

    // MARK: - Eve versus Glow

    func testEveNeverImportsGlowsRecords() {
        let glowRecord = observation(day(2026, 3, 1), .flow, .flow(.heavy), from: glow, named: "Glow")
        XCTAssertTrue(HealthSyncService.filtered([glowRecord], by: .glowEve).isEmpty)
    }

    func testGlowNeverImportsEvesRecords() {
        let eveRecord = observation(day(2026, 1, 5), .flow, .flow(.heavy))
        XCTAssertTrue(HealthSyncService.filtered([eveRecord], by: .glow).isEmpty)
    }

    func testTheTwoSiblingAppsClaimDifferentIdentifiers() {
        // Same company, same version number, same support site — and two distinct
        // HealthKit sources. Sharing an identifier would put each one's history
        // under the other's name.
        XCTAssertTrue(HealthSyncService.SourceFilter.glowEve.bundleIDs
            .isDisjoint(with: HealthSyncService.SourceFilter.glow.bundleIDs))
        XCTAssertEqual(HealthSyncService.SourceFilter.glowEve.appName, "Eve")
        XCTAssertEqual(HealthSyncService.SourceFilter.glow.appName, "Glow")
    }

    func testEveExcludesEveryOtherSource() {
        importing(dataset() + otherApps())
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .heavy)
        for d in 1...6 {
            XCTAssertNil(entry(day(2026, 3, d)), "March \(d) came from another app")
        }
    }

    func testAllFilteredRoutesRemainMutuallyExclusive() {
        let pool = dataset() + otherApps()
        let routes: [(String, HealthSyncService.SourceFilter, String)] = [
            ("Eve", .glowEve, eve), ("Glow", .glow, glow),
            ("Natural Cycles", .naturalCycles, naturalCycles),
            ("Period Tracker", .periodTrackerGPApps, gpApps)
        ]
        var seen: Set<String> = []
        for (name, filter, expected) in routes {
            let ids = Set(HealthSyncService.filtered(pool, by: filter).map(\.sourceBundleID))
            XCTAssertEqual(ids, [expected], "\(name) picked up something else")
            XCTAssertTrue(ids.isDisjoint(with: seen), "\(name) overlaps an earlier route")
            seen.formUnion(ids)
        }
    }

    func testGenericAppleHealthStillTakesEverything() {
        importing(dataset() + otherApps(), filter: nil)
        XCTAssertEqual(entry(day(2026, 3, 1))?.flow, .heavy, "Glow belongs in a generic import")
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .heavy)
    }

    // MARK: - The three types Eve documents

    func testTheThreeDocumentedTypesArrive() {
        importing(dataset())
        // Menstruation
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .heavy)
        XCTAssertEqual(entry(day(2026, 1, 8))?.flow, .unspecified)
        // Spotting — a symptom, never a period day
        XCTAssertEqual(entry(day(2026, 1, 20))?.symptoms, [.irregularBleed])
        XCTAssertNil(entry(day(2026, 1, 20))?.flow)
        // Sexual activity
        XCTAssertEqual(entry(day(2026, 1, 14))?.sexualActivity, true)
        XCTAssertEqual(entry(day(2026, 1, 18))?.sexualActivity, true)

        let cycles = PredictionEngine.cycles(from: entries(), today: today)
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles.first?.length, 28)
        XCTAssertEqual(cycles.first?.periodLength, 4)
    }

    func testTheRowPromisesOnlyWhatEveActuallyShares() {
        let note = (ImportSourceGuide.glowEve.note ?? "").lowercased()
        for arrives in ["period", "spotting", "sex"] {
            XCTAssertTrue(note.contains(arrives), "the note should say '\(arrives)' comes across")
        }
        // Eve tracks and charts these but does not pass them to Health.
        for absent in ["mood", "symptom", "temperature"] {
            XCTAssertTrue(note.contains(absent), "the note must say '\(absent)' does not travel")
        }
    }

    // MARK: - Merge behaviour

    func testHandLoggedValueWins() {
        let target = day(2026, 1, 5)
        let mine = CycleStore.entry(for: target, in: context, calendar: calendar)
        mine.flow = .light
        context.saveOrLog()
        let summary = importing([observation(target, .flow, .flow(.heavy))])
        XCTAssertEqual(entry(target)?.flow, .light)
        XCTAssertEqual(summary.keptUserValue, 1)
    }

    func testNoIntensityInvented() {
        importing(dataset())
        XCTAssertEqual(Set(entries().compactMap(\.flow)), [.heavy, .medium, .light, .unspecified])
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

    func testPlanningWritesNothingAndCommitMatchesExactly() {
        let decisions = plan(dataset())
        XCTAssertEqual(entries().count, 0)
        XCTAssertEqual(ledger.claimCount, 0)
        let promised = ImportReconciler.summarize(decisions)
        let actual = ImportReconciler.commit(decisions, into: context, ledger: ledger,
                                             batchID: UUID(), calendar: calendar)
        XCTAssertTrue(actual.succeeded)
        XCTAssertEqual(actual.summary.daysAffected, promised.daysAffected)
        XCTAssertEqual(actual.summary.changeCount, promised.changeCount)
        XCTAssertEqual(ledger.claimCount, actual.summary.changeCount)
    }

    func testUndoRemovesOnlyEveAndSparesLaterEdits() {
        let mine = CycleStore.entry(for: day(2026, 1, 1), in: context, calendar: calendar)
        mine.flow = .heavy
        context.saveOrLog()

        let batch = UUID()
        importing(dataset(), batchID: batch)
        entry(day(2026, 1, 7))?.flow = .heavy
        context.saveOrLog()

        XCTAssertTrue(ImportPlanner.undo(batchID: batch, context: context,
                                         ledger: ledger, calendar: calendar).succeeded)
        XCTAssertNil(entry(day(2026, 1, 5)))
        XCTAssertEqual(entry(day(2026, 1, 7))?.flow, .heavy, "her correction survives")
        XCTAssertEqual(entry(day(2026, 1, 1))?.flow, .heavy, "her own day survives")
    }

    func testDaysDoNotShiftAcrossDST() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let days = [7, 8, 9].map {
            la.startOfDay(for: la.date(from: DateComponents(year: 2026, month: 3, day: $0))!)
        }
        let obs = days.map {
            ImportObservation(day: $0, field: .flow, value: .flow(.medium), recordID: UUID(),
                              sourceBundleID: eve, sourceName: "Eve", recordedAt: $0)
        }
        let decisions = ImportReconciler.plan(
            observations: HealthSyncService.filtered(obs, by: .glowEve),
            currentValue: { _, _ in nil }, ledger: ledger, ownBundleID: caelyn,
            acceptOwnSource: true, calendar: la, today: today
        )
        ImportReconciler.commit(decisions, into: context, ledger: ledger, batchID: UUID(), calendar: la)
        XCTAssertEqual(entries().map { ImportLedger.dayKey($0.date, calendar: la) }.sorted(),
                       ["2026-03-07", "2026-03-08", "2026-03-09"])
    }

    // MARK: - Provenance and empty states

    func testProvenanceSaysEveNotGlow() {
        XCTAssertEqual(HealthSyncService.SourceFilter.glowEve.label, "Eve via Apple Health")
        importing([observation(day(2026, 1, 5), .flow, .flow(.heavy))])
        let claim = ledger.claim(day: day(2026, 1, 5), field: .flow, calendar: calendar)
        XCTAssertEqual(claim?.sourceBundleID, eve)
        XCTAssertEqual(claim?.sourceName, "Eve")
    }

    func testPreviewNamesEve() {
        var plan = HealthSyncService.Plan()
        plan.summary.filled = 6; plan.summary.daysAffected = 6; plan.summary.byField = ["flow": 6]
        let preview = ImportPreview.fromHealth(plan, sourceFilter: .glowEve)
        XCTAssertTrue(preview.sourceLine.contains("Eve"))
        XCTAssertFalse(preview.sourceLine.contains("Glow "))
    }

    func testEmptyAndPartialAccessStayCalm() {
        // Nothing found at all.
        let empty = ImportPreview.fromHealth(HealthSyncService.Plan(), sourceFilter: .glowEve)
        XCTAssertEqual(empty.headline, "Nothing new to bring over")

        // Some types unreadable — a partial grant looks like this.
        var partial = HealthSyncService.Plan()
        partial.summary.filled = 2; partial.summary.daysAffected = 2; partial.summary.byField = ["flow": 2]
        partial.unreadableTypes = ["HKCategoryTypeIdentifierSexualActivity"]
        let preview = ImportPreview.fromHealth(partial, sourceFilter: .glowEve)
        XCTAssertTrue(preview.hasChanges)
        let text = ([preview.headline, preview.sourceLine, preview.safetyLine] + preview.caveats).joined(separator: " ")
        for banned in ["enable", "denied", "permission", "HKCategory", "grant", "this file"] {
            XCTAssertFalse(text.lowercased().contains(banned.lowercased()), "'\(banned)' leaked into her copy")
        }
    }
}
