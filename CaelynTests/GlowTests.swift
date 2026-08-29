import XCTest
import SwiftData
@testable import Caelyn

/// Glow Ovulation & Period App — App Store 638021335, `com.upwlabs.emma`.
///
/// Glow will email a CSV of your data if you write to their support team, but
/// nothing describes what is in it, so Caelyn does not parse it. The route is
/// Apple Health, which Glow's own support site documents as covering reproductive
/// health categories.
///
/// Glow also ships **Eve**, a separate app with its own HealthKit source. Keeping
/// the two apart is the sharpest test here: importing Eve's records under Glow's
/// name would be exactly the mislabelling source filtering exists to prevent.
@MainActor
final class GlowTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var ledger: ImportLedger!
    private let calendar = Calendar(identifier: .gregorian)

    private let glow = "com.upwlabs.emma"
    private let glowEve = "com.glowing.lexie"
    private let naturalCycles = "com.naturalcycles.cordova"
    private let gpApps = "com.gpapps.ptrackerlite"
    private let flo = "org.iggymedia.periodtracker"
    private let clue = "com.helloclue.clue"
    private let caelyn = "smallpanta-icould.com.caelynperiodtracker"

    override func setUpWithError() throws {
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
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
                             from bundle: String? = nil, named: String = "Glow") -> ImportObservation {
        let source = bundle ?? glow
        return ImportObservation(
            day: date, field: field, value: value,
            recordID: ImportRecordID.make(source: .appleHealth,
                                          dayKey: ImportLedger.dayKey(date, calendar: calendar),
                                          fieldKey: source + "|" + field.ledgerKey),
            sourceBundleID: source, sourceName: named, recordedAt: date
        )
    }

    /// Glow tracks cycle length, flow, symptoms, basal body temperature, cervical
    /// mucus and sexual activity — so the fixture covers the reproductive types
    /// Apple Health can carry between it and Caelyn.
    private func dataset() -> [ImportObservation] {
        [
            observation(day(2026, 1, 5), .flow, .flow(.heavy)),
            observation(day(2026, 1, 6), .flow, .flow(.medium)),
            observation(day(2026, 1, 7), .flow, .flow(.light)),
            observation(day(2026, 1, 8), .flow, .flow(.unspecified)),
            observation(day(2026, 2, 2), .flow, .flow(.medium)),
            observation(day(2026, 2, 3), .flow, .flow(.medium)),
            observation(day(2026, 1, 20), .symptom(.irregularBleed), .symptomSeverity(1)),
            observation(day(2026, 1, 6), .symptom(.cramps), .symptomSeverity(3)),
            observation(day(2026, 1, 18), .basalTemperature, .temperature(36.68)),
            observation(day(2026, 1, 18), .cervicalMucus, .mucus(.eggWhite)),
            observation(day(2026, 1, 18), .ovulationTest, .ovulation(.lhSurge)),
            observation(day(2026, 1, 18), .sexualActivity, .boolean(true)),
            observation(day(2026, 1, 30), .pregnancyTest, .boolean(false))
        ]
    }

    private func otherApps() -> [ImportObservation] {
        [
            observation(day(2026, 3, 1), .flow, .flow(.heavy), from: glowEve, named: "Eve"),
            observation(day(2026, 3, 2), .flow, .flow(.heavy), from: naturalCycles, named: "Natural Cycles"),
            observation(day(2026, 3, 3), .flow, .flow(.heavy), from: gpApps, named: "Period Tracker"),
            observation(day(2026, 3, 4), .flow, .flow(.heavy), from: flo, named: "Flo"),
            observation(day(2026, 3, 5), .flow, .flow(.heavy), from: clue, named: "Clue"),
            observation(day(2026, 3, 6), .flow, .flow(.heavy), from: caelyn, named: "Caelyn")
        ]
    }

    private func plan(_ obs: [ImportObservation],
                      filter: HealthSyncService.SourceFilter? = .glow) -> [ImportReconciler.Decision] {
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
                           filter: HealthSyncService.SourceFilter? = .glow,
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

    func testGlowRouteImportsOnlyGlowRecords() {
        importing(dataset() + otherApps())
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .heavy)
        for d in 1...6 {
            XCTAssertNil(entry(day(2026, 3, d)), "March \(d) came from another app")
        }
    }

    func testGlowAndEveAreNotTheSameApp() {
        // Two products by the same company, two HealthKit sources. Importing Eve's
        // records under Glow's name would be the exact mislabelling this prevents.
        let eve = observation(day(2026, 3, 1), .flow, .flow(.heavy), from: glowEve, named: "Eve")
        XCTAssertTrue(HealthSyncService.filtered([eve], by: .glow).isEmpty)
        XCTAssertFalse(HealthSyncService.SourceFilter.glow.bundleIDs.contains(glowEve))
    }

    func testAllThreeFilteredRoutesStayDisjoint() {
        let pool = dataset() + otherApps()
        let g = HealthSyncService.filtered(pool, by: .glow).map(\.sourceBundleID)
        let n = HealthSyncService.filtered(pool, by: .naturalCycles).map(\.sourceBundleID)
        let p = HealthSyncService.filtered(pool, by: .periodTrackerGPApps).map(\.sourceBundleID)
        XCTAssertEqual(Set(g), [glow]); XCTAssertEqual(Set(n), [naturalCycles]); XCTAssertEqual(Set(p), [gpApps])
        XCTAssertTrue(Set(g).isDisjoint(with: Set(n)))
        XCTAssertTrue(Set(g).isDisjoint(with: Set(p)))
        XCTAssertTrue(Set(n).isDisjoint(with: Set(p)))
    }

    func testGenericAppleHealthStillTakesEverything() {
        importing(dataset() + otherApps(), filter: nil)
        XCTAssertEqual(entry(day(2026, 3, 1))?.flow, .heavy, "Eve belongs in a generic import")
        XCTAssertEqual(entry(day(2026, 3, 4))?.flow, .heavy, "so does Flo")
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .heavy)
    }

    // MARK: - Import

    func testEveryReproductiveFieldArrives() {
        importing(dataset())
        XCTAssertEqual(entry(day(2026, 1, 8))?.flow, .unspecified)
        XCTAssertEqual(entry(day(2026, 1, 6))?.symptomSeverity["cramps"], 3)
        XCTAssertEqual(entry(day(2026, 1, 20))?.symptoms, [.irregularBleed])
        XCTAssertNil(entry(day(2026, 1, 20))?.flow, "spotting is not a period day")
        XCTAssertEqual(entry(day(2026, 1, 18))?.basalTemperature ?? 0, 36.68, accuracy: 0.001)
        XCTAssertEqual(entry(day(2026, 1, 18))?.cervicalMucus, .eggWhite)
        XCTAssertEqual(entry(day(2026, 1, 18))?.ovulationTestResult, .lhSurge)
        XCTAssertEqual(entry(day(2026, 1, 18))?.sexualActivity, true)
        XCTAssertEqual(entry(day(2026, 1, 30))?.pregnancyTest, false)

        let cycles = PredictionEngine.cycles(from: entries(), today: today)
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles.first?.length, 28)
        XCTAssertEqual(cycles.first?.periodLength, 4)
    }

    func testHandLoggedValueWins() {
        let target = day(2026, 1, 5)
        let mine = CycleStore.entry(for: target, in: context, calendar: calendar)
        mine.flow = .light
        context.saveOrLog()
        let summary = importing([observation(target, .flow, .flow(.heavy))])
        XCTAssertEqual(entry(target)?.flow, .light, "hers stands even when Glow says heavier")
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
        for e in entries() {
            XCTAssertEqual(Set(e.symptoms).count, e.symptoms.count)
        }
    }

    func testPlanningWritesNothingAndCommitMatches() {
        let decisions = plan(dataset())
        XCTAssertEqual(entries().count, 0)
        XCTAssertEqual(ledger.claimCount, 0)
        let promised = ImportReconciler.summarize(decisions)
        let actual = ImportReconciler.commit(decisions, into: context, ledger: ledger,
                                             batchID: UUID(), calendar: calendar)
        XCTAssertTrue(actual.succeeded)
        XCTAssertEqual(actual.summary.daysAffected, promised.daysAffected)
        XCTAssertEqual(actual.summary.changeCount, promised.changeCount)
        XCTAssertEqual(ledger.claimCount, actual.summary.changeCount,
                       "one claim per written value, so a rollback would leave none")
    }

    func testUndoRemovesOnlyGlowAndSparesLaterEdits() {
        let mine = CycleStore.entry(for: day(2026, 1, 1), in: context, calendar: calendar)
        mine.flow = .heavy
        context.saveOrLog()

        let batch = UUID()
        importing(dataset(), batchID: batch)
        entry(day(2026, 1, 7))?.flow = .heavy
        context.saveOrLog()

        XCTAssertTrue(ImportPlanner.undo(batchID: batch, context: context,
                                         ledger: ledger, calendar: calendar).succeeded)
        XCTAssertNil(entry(day(2026, 1, 5)), "untouched imported day removed")
        XCTAssertEqual(entry(day(2026, 1, 7))?.flow, .heavy, "her correction survives")
        XCTAssertEqual(entry(day(2026, 1, 1))?.flow, .heavy, "her own day survives")
    }

    // MARK: - Dates

    func testDaysDoNotShiftAcrossDST() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let days = [7, 8, 9].map {
            la.startOfDay(for: la.date(from: DateComponents(year: 2026, month: 3, day: $0))!)
        }
        let obs = days.map {
            ImportObservation(day: $0, field: .flow, value: .flow(.medium), recordID: UUID(),
                              sourceBundleID: glow, sourceName: "Glow", recordedAt: $0)
        }
        let decisions = ImportReconciler.plan(
            observations: HealthSyncService.filtered(obs, by: .glow),
            currentValue: { _, _ in nil }, ledger: ledger, ownBundleID: caelyn,
            acceptOwnSource: true, calendar: la, today: today
        )
        ImportReconciler.commit(decisions, into: context, ledger: ledger, batchID: UUID(), calendar: la)
        XCTAssertEqual(entries().map { ImportLedger.dayKey($0.date, calendar: la) }.sorted(),
                       ["2026-03-07", "2026-03-08", "2026-03-09"])
    }

    // MARK: - Provenance and copy

    func testImportIsNamedAfterGlow() {
        XCTAssertEqual(HealthSyncService.SourceFilter.glow.label, "Glow via Apple Health")
        importing([observation(day(2026, 1, 5), .flow, .flow(.heavy))])
        let claim = ledger.claim(day: day(2026, 1, 5), field: .flow, calendar: calendar)
        XCTAssertEqual(claim?.sourceBundleID, glow)
        XCTAssertEqual(claim?.sourceName, "Glow")
    }

    func testPreviewNamesGlow() {
        var plan = HealthSyncService.Plan()
        plan.summary.filled = 8; plan.summary.daysAffected = 8; plan.summary.byField = ["flow": 8]
        let preview = ImportPreview.fromHealth(plan, sourceFilter: .glow)
        XCTAssertTrue(preview.sourceLine.contains("Glow"))
        XCTAssertFalse(preview.sourceLine.contains("Natural Cycles"))
        XCTAssertFalse(preview.sourceLine.contains("Period Tracker"))
    }

    func testEmptyResultStaysCalmAndNamesGlow() {
        let preview = ImportPreview.fromHealth(HealthSyncService.Plan(), sourceFilter: .glow)
        XCTAssertEqual(preview.headline, "Nothing new to bring over")
        let text = ([preview.headline, preview.sourceLine, preview.safetyLine] + preview.caveats).joined(separator: " ")
        for banned in ["enable", "denied", "permission", "HKCategory", "grant", "this file"] {
            XCTAssertFalse(text.lowercased().contains(banned.lowercased()), "'\(banned)' leaked")
        }
    }

    // MARK: - The row

    func testTheRowCarriesGlowsOwnInstructionsIncludingTheStepPeopleMiss() {
        let guide = ImportSourceGuide.glow
        XCTAssertEqual(guide.healthSourceFilter, .glow)
        XCTAssertFalse(guide.needsAFile, "there is no verified file format to send her to")
        let steps = guide.steps.joined(separator: " ")
        XCTAssertTrue(steps.contains("Connect with health apps"), "Glow's own menu wording")
        XCTAssertTrue(steps.contains("All Categories on"),
                      "switching Glow on isn't enough; iOS keeps categories off until this is tapped")
        XCTAssertTrue((guide.note ?? "").contains("support team"),
                      "the CSV route exists and she should know Caelyn can't read it yet")
    }

    func testGlowDoesNotDisturbTheOtherRows() {
        let byTitle = Dictionary(uniqueKeysWithValues: ImportSourceGuide.pickable.map { ($0.title, $0) })
        XCTAssertNil(byTitle["Apple Health"]?.healthSourceFilter, "the generic row stays generic")
        XCTAssertEqual(byTitle["Period Tracker"]?.healthSourceFilter, .periodTrackerGPApps)
        XCTAssertEqual(byTitle["Natural Cycles"]?.healthSourceFilter, .naturalCycles)
        XCTAssertEqual(byTitle["Glow"]?.healthSourceFilter, .glow)
        XCTAssertEqual(byTitle["Clue"]?.route, .fileAfterInstructions)
        XCTAssertEqual(byTitle["Flo"]?.route, .fileAfterInstructions)
        let keys = ImportSourceGuide.pickable.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
    }
}
