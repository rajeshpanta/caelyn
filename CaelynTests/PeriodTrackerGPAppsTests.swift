import XCTest
import SwiftData
import HealthKit
@testable import Caelyn

/// Period Tracker by GP Apps — App Store 330376830, `com.gpapps.ptrackerlite`.
///
/// Caelyn cannot read its backup file: the format is undocumented and no parser
/// exists, so the migration goes through Apple Health instead. Health is a shared
/// pool, which makes the interesting question not "can we read it" but **"can we
/// read only it"** — a route promising Period Tracker history must not quietly
/// rake in whatever Flo, Clue or Caelyn itself has written there.
///
/// Every test drives the real filter, the real `ImportReconciler` and the real
/// commit path. Nothing here reimplements merge logic. What the fixtures stand in
/// for is the one seam a test cannot reach: `HKSample.sourceRevision` is set by
/// HealthKit at save time and cannot be forged, so observations are built with the
/// bundle identifiers HealthKit would have stamped.
@MainActor
final class PeriodTrackerGPAppsTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var ledger: ImportLedger!
    private let calendar = Calendar(identifier: .gregorian)

    private let gpApps = "com.gpapps.ptrackerlite"
    private let flo = "org.iggymedia.periodtracker"
    private let clue = "com.biowink.clue"
    private let caelyn = "smallpanta-icould.com.caelynperiodtracker"
    private let healthApp = "com.apple.Health"
    private let unrelated = "com.example.somethingelse"

    override func setUpWithError() throws {
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
        ledger = ImportLedger(fileURL: nil)
    }

    override func tearDownWithError() throws {
        container = nil; context = nil; ledger = nil
    }

    // MARK: - Fixture

    private var today: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!)
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: y, month: m, day: d))!)
    }

    private func observation(
        _ date: Date,
        _ field: ImportObservation.Field,
        _ value: ImportObservation.Value,
        from bundle: String? = nil,
        named: String = "Period Tracker",
        recordedAt: Date? = nil
    ) -> ImportObservation {
        let source = bundle ?? gpApps
        return ImportObservation(
            day: date, field: field, value: value,
            // Deterministic, so the same fixture row is the same record every run —
            // which is what makes the duplicate test meaningful.
            recordID: ImportRecordID.make(
                source: .appleHealth,
                dayKey: ImportLedger.dayKey(date, calendar: calendar),
                fieldKey: source + "|" + field.ledgerKey
            ),
            sourceBundleID: source,
            sourceName: named,
            recordedAt: recordedAt ?? date
        )
    }

    /// A controlled month of Period Tracker history, covering every Caelyn field
    /// Apple Health can carry, with recognisable values.
    private func gpAppsDataset() -> [ImportObservation] {
        var out: [ImportObservation] = []

        // Three period days with explicit, distinct intensities.
        out.append(observation(day(2026, 1, 5), .flow, .flow(.heavy)))
        out.append(observation(day(2026, 1, 6), .flow, .flow(.medium)))
        out.append(observation(day(2026, 1, 7), .flow, .flow(.light)))
        // A fourth where the app recorded a bleed but no intensity.
        out.append(observation(day(2026, 1, 8), .flow, .flow(.unspecified)))
        // Mid-cycle spotting — a symptom, never a period day.
        out.append(observation(day(2026, 1, 20), .symptom(.irregularBleed), .symptomSeverity(1)))

        // Fertility signals.
        out.append(observation(day(2026, 1, 18), .basalTemperature, .temperature(36.42)))
        out.append(observation(day(2026, 1, 19), .basalTemperature, .temperature(36.71)))
        out.append(observation(day(2026, 1, 18), .cervicalMucus, .mucus(.eggWhite)))
        out.append(observation(day(2026, 1, 18), .ovulationTest, .ovulation(.lhSurge)))
        out.append(observation(day(2026, 1, 30), .pregnancyTest, .boolean(false)))
        out.append(observation(day(2026, 1, 18), .sexualActivity, .boolean(true)))
        out.append(observation(day(2026, 1, 5), .painType(.pelvicPain), .present))

        // Every symptom category Caelyn maps out of Health.
        for (offset, symptom) in HealthDataCatalog.symptomReads.values.sorted(by: { $0.rawValue < $1.rawValue }).enumerated() {
            out.append(observation(day(2026, 2, 1 + offset), .symptom(symptom), .symptomSeverity(2)))
        }
        return out
    }

    /// The same Health pool, as it really is: other apps' records mixed in.
    private func otherAppsDataset() -> [ImportObservation] {
        [
            observation(day(2026, 3, 2), .flow, .flow(.heavy), from: flo, named: "Flo"),
            observation(day(2026, 3, 3), .flow, .flow(.medium), from: clue, named: "Clue"),
            observation(day(2026, 3, 4), .flow, .flow(.light), from: caelyn, named: "Caelyn"),
            observation(day(2026, 3, 5), .flow, .flow(.heavy), from: healthApp, named: "Health"),
            observation(day(2026, 3, 6), .flow, .flow(.medium), from: unrelated, named: "Something Else"),
            observation(day(2026, 3, 7), .basalTemperature, .temperature(36.6), from: flo, named: "Flo")
        ]
    }

    // MARK: - Pipeline

    private func plan(_ observations: [ImportObservation],
                      filter: HealthSyncService.SourceFilter? = .periodTrackerGPApps
    ) -> [ImportReconciler.Decision] {
        let kept = HealthSyncService.filtered(observations, by: filter)
        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Date: CycleEntry] = [:]
        for e in entries { byDay[calendar.startOfDay(for: e.date)] = e }
        return ImportReconciler.plan(
            observations: kept,
            currentValue: { d, f in byDay[self.calendar.startOfDay(for: d)]?.value(for: f) },
            ledger: ledger,
            ownBundleID: caelyn,
            // The Period Tracker route is a user-initiated full import.
            acceptOwnSource: true,
            calendar: calendar,
            today: today
        )
    }

    @discardableResult
    private func importing(_ observations: [ImportObservation],
                           filter: HealthSyncService.SourceFilter? = .periodTrackerGPApps,
                           batchID: UUID = UUID()
    ) -> ImportReconciler.Summary {
        ImportReconciler.commit(plan(observations, filter: filter), into: context,
                                ledger: ledger, batchID: batchID, calendar: calendar).summary
    }

    private func entries() -> [CycleEntry] {
        ((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []).sorted { $0.date < $1.date }
    }

    private func entry(_ date: Date) -> CycleEntry? {
        entries().first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Source filtering

    func testPeriodTrackerRouteImportsOnlyGPAppsRecords() {
        importing(gpAppsDataset() + otherAppsDataset())

        // Everything from the fixture's own month is present…
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .heavy)
        XCTAssertEqual(entry(day(2026, 1, 8))?.flow, .unspecified)
        // …and not one record from any other app in March.
        for d in 2...7 {
            XCTAssertNil(entry(day(2026, 3, d)),
                         "March \(d) came from another app and must not be in a Period Tracker import")
        }
    }

    func testEveryOtherAppIsExcludedIndividually() {
        let mixed = otherAppsDataset()
        let kept = HealthSyncService.filtered(mixed, by: .periodTrackerGPApps)
        XCTAssertTrue(kept.isEmpty, "kept records from: \(kept.map(\.sourceName))")
    }

    func testTheFilterAcceptsBothGPAppsIdentifiers() {
        let paid = observation(day(2026, 1, 5), .flow, .flow(.heavy), from: "com.gpapps.ptracker")
        XCTAssertEqual(HealthSyncService.filtered([paid], by: .periodTrackerGPApps).count, 1)
    }

    func testGenericAppleHealthStillImportsEverything() {
        // The unfiltered route is unchanged: no filter means the whole pool.
        importing(gpAppsDataset() + otherAppsDataset(), filter: nil)
        XCTAssertEqual(entry(day(2026, 3, 2))?.flow, .heavy, "Flo's day belongs in a generic Health import")
        XCTAssertEqual(entry(day(2026, 3, 6))?.flow, .medium)
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .heavy)
    }

    // MARK: - Field coverage

    func testEveryFieldAppleHealthCanCarryArrives() {
        importing(gpAppsDataset())

        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .heavy)
        XCTAssertEqual(entry(day(2026, 1, 6))?.flow, .medium)
        XCTAssertEqual(entry(day(2026, 1, 7))?.flow, .light)
        XCTAssertEqual(entry(day(2026, 1, 8))?.flow, .unspecified)
        XCTAssertEqual(entry(day(2026, 1, 20))?.symptoms, [.irregularBleed])
        XCTAssertNil(entry(day(2026, 1, 20))?.flow, "spotting must never become a period day")
        XCTAssertEqual(entry(day(2026, 1, 18))?.basalTemperature ?? 0, 36.42, accuracy: 0.001)
        XCTAssertEqual(entry(day(2026, 1, 18))?.cervicalMucus, .eggWhite)
        XCTAssertEqual(entry(day(2026, 1, 18))?.ovulationTestResult, .lhSurge)
        XCTAssertEqual(entry(day(2026, 1, 30))?.pregnancyTest, false)
        XCTAssertEqual(entry(day(2026, 1, 18))?.sexualActivity, true)
        XCTAssertEqual(entry(day(2026, 1, 5))?.painTypes, [.pelvicPain])

        let imported = Set(entries().flatMap(\.symptoms))
        for symptom in HealthDataCatalog.symptomReads.values {
            XCTAssertTrue(imported.contains(symptom), "\(symptom.rawValue) did not survive the import")
        }
    }

    func testImportedPeriodDaysReconstructIntoACycle() {
        var data = gpAppsDataset()
        for offset in 0..<4 {
            data.append(observation(day(2026, 2, 2 + offset), .flow, .flow(.medium)))
        }
        importing(data)
        let cycles = PredictionEngine.cycles(from: entries(), today: today)
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles.first?.length, 28, "5 Jan to 2 Feb")
        XCTAssertEqual(cycles.first?.periodLength, 4, "the unspecified day counts as bleeding")
    }

    // MARK: - Manual data wins

    func testHandLoggedValueSurvivesAPeriodTrackerImport() {
        let target = day(2026, 1, 5)
        let mine = CycleStore.entry(for: target, in: context, calendar: calendar)
        mine.flow = .heavy
        context.saveOrLog()

        // Period Tracker says something quieter for the same day.
        let summary = importing([observation(target, .flow, .flow(.light))])

        XCTAssertEqual(entry(target)?.flow, .heavy, "her value must stand")
        XCTAssertEqual(summary.keptUserValue, 1)
        XCTAssertEqual(summary.filled, 0)
    }

    func testUnspecifiedNeverReplacesAnIntensitySheChose() {
        let target = day(2026, 1, 5)
        let mine = CycleStore.entry(for: target, in: context, calendar: calendar)
        mine.flow = .heavy
        context.saveOrLog()

        importing([observation(target, .flow, .flow(.unspecified))])
        XCTAssertEqual(entry(target)?.flow, .heavy, "a vaguer value must never overwrite a specific one")
    }

    // MARK: - Unknown intensity

    func testABleedWithNoIntensityStaysUnspecified() {
        importing([observation(day(2026, 1, 8), .flow, .flow(.unspecified))])
        XCTAssertEqual(entry(day(2026, 1, 8))?.flow, .unspecified)
    }

    func testNoIntensityIsEverInvented() {
        importing(gpAppsDataset())
        let levels = Set(entries().compactMap(\.flow))
        // Exactly the four the fixture states, and nothing conjured.
        XCTAssertEqual(levels, [.heavy, .medium, .light, .unspecified])
        XCTAssertFalse(levels.contains(.spotting), "nothing in the fixture said spotting")
    }

    // MARK: - Duplicates

    func testReimportingTheSameHistoryChangesNothing() {
        let data = gpAppsDataset()
        let first = importing(data)
        let dayCount = entries().count
        let claims = ledger.claimCount

        let second = importing(data)

        XCTAssertGreaterThan(first.filled, 0)
        XCTAssertEqual(second.filled, 0)
        XCTAssertEqual(second.updated, 0)
        XCTAssertGreaterThan(second.duplicates, 0)
        XCTAssertEqual(entries().count, dayCount, "no duplicate days")
        XCTAssertEqual(ledger.claimCount, claims, "no duplicate provenance")
        for entry in entries() {
            XCTAssertEqual(Set(entry.symptoms).count, entry.symptoms.count, "duplicate symptom on \(entry.date)")
            XCTAssertEqual(Set(entry.painTypes).count, entry.painTypes.count, "duplicate pain type")
        }
    }

    // MARK: - Preview before write

    func testPlanningWritesNothing() {
        let decisions = plan(gpAppsDataset())
        XCTAssertFalse(decisions.isEmpty)
        XCTAssertEqual(entries().count, 0, "planning must not touch the store")
        XCTAssertEqual(ledger.claimCount, 0)
        XCTAssertTrue(ledger.batches.isEmpty)
    }

    func testCommitWritesExactlyWhatThePlanPromised() {
        let decisions = plan(gpAppsDataset())
        let promised = ImportReconciler.summarize(decisions)
        let actual = ImportReconciler.commit(decisions, into: context, ledger: ledger,
                                             batchID: UUID(), calendar: calendar).summary
        XCTAssertEqual(actual.daysAffected, promised.daysAffected)
        XCTAssertEqual(actual.changeCount, promised.changeCount)
        XCTAssertEqual(entries().count, promised.daysAffected)
    }

    // MARK: - Undo

    func testUndoRemovesThePeriodTrackerImportAndNothingElse() {
        let mine = CycleStore.entry(for: day(2026, 1, 1), in: context, calendar: calendar)
        mine.flow = .heavy
        mine.note = "mine"
        context.saveOrLog()

        let batch = UUID()
        importing(gpAppsDataset(), batchID: batch)
        XCTAssertEqual(entry(day(2026, 1, 5))?.flow, .heavy)

        let result = ImportPlanner.undo(batchID: batch, context: context, ledger: ledger, calendar: calendar)

        XCTAssertTrue(result.succeeded)
        XCTAssertNil(entry(day(2026, 1, 5)), "an imported day is removed")
        XCTAssertEqual(entry(day(2026, 1, 1))?.flow, .heavy, "her own day is untouched")
        XCTAssertEqual(entry(day(2026, 1, 1))?.note, "mine")
    }

    func testAnEditMadeAfterImportSurvivesUndo() {
        let batch = UUID()
        importing(gpAppsDataset(), batchID: batch)

        entry(day(2026, 1, 6))?.flow = .heavy          // she corrects it
        entry(day(2026, 1, 7))?.note = "cramped today" // and adds her own
        context.saveOrLog()

        ImportPlanner.undo(batchID: batch, context: context, ledger: ledger, calendar: calendar)

        XCTAssertEqual(entry(day(2026, 1, 6))?.flow, .heavy, "her correction is hers")
        XCTAssertEqual(entry(day(2026, 1, 7))?.note, "cramped today")
        XCTAssertNil(entry(day(2026, 1, 7))?.flow, "but the imported value on that day is gone")
        XCTAssertNil(entry(day(2026, 1, 5)), "untouched imported days are removed")
    }

    // MARK: - Provenance

    func testAnImportIsNamedAfterPeriodTrackerNotAppleHealth() {
        XCTAssertEqual(HealthSyncService.SourceFilter.periodTrackerGPApps.label,
                       "Period Tracker via Apple Health")
        let batch = ImportLedger.Batch(
            id: UUID(), sourceID: ImportSourceID.appleHealth.rawValue,
            sourceName: HealthSyncService.SourceFilter.periodTrackerGPApps.label,
            importedAt: Date(), valuesWritten: 12, daysAffected: 8
        )
        ledger.addBatch(batch)
        XCTAssertEqual(ledger.batches.first?.sourceName, "Period Tracker via Apple Health")
        XCTAssertNotEqual(ledger.batches.first?.sourceName, ImportSourceID.appleHealth.displayName)
    }

    func testProvenanceRecordsTheOriginatingApp() {
        importing([observation(day(2026, 1, 5), .flow, .flow(.heavy))])
        let claim = ledger.claim(day: day(2026, 1, 5), field: .flow, calendar: calendar)
        XCTAssertEqual(claim?.sourceBundleID, gpApps)
        XCTAssertEqual(claim?.sourceName, "Period Tracker")
    }

    func testFilteringDoesNotBreakTheLoopBreaker() {
        // Caelyn's own records are still recognisable as its own, filter or not.
        let own = observation(day(2026, 4, 1), .flow, .flow(.heavy), from: caelyn, named: "Caelyn")
        let dropped = ImportReconciler.plan(
            observations: [own], currentValue: { _, _ in nil }, ledger: ledger,
            ownBundleID: caelyn, acceptOwnSource: false, calendar: calendar, today: today
        )
        XCTAssertTrue(dropped.isEmpty, "an incremental sync must still ignore Caelyn's own writes")
    }

    // MARK: - Dates

    func testAPeriodDayDoesNotShiftAcrossTimezones() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        // Written in Tokyo, read in Los Angeles.
        let written = tokyo.startOfDay(for: tokyo.date(from: DateComponents(year: 2026, month: 1, day: 5))!)
        XCTAssertEqual(ImportLedger.dayKey(written, calendar: tokyo), "2026-01-05")

        let observation = ImportObservation(
            day: written, field: .flow, value: .flow(.heavy),
            recordID: UUID(), sourceBundleID: gpApps, sourceName: "Period Tracker", recordedAt: written
        )
        let decisions = ImportReconciler.plan(
            observations: HealthSyncService.filtered([observation], by: .periodTrackerGPApps),
            currentValue: { _, _ in nil }, ledger: ledger, ownBundleID: caelyn,
            acceptOwnSource: true, calendar: la, today: today
        )
        XCTAssertEqual(decisions.count, 1)
        XCTAssertEqual(ImportLedger.dayKey(decisions[0].day, calendar: la),
                       ImportLedger.dayKey(la.startOfDay(for: written), calendar: la))
    }

    func testMidnightAndDSTDaysStayWhereTheyBelong() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // US spring-forward 2026-03-08, plus the days either side.
        let days = [la.date(from: DateComponents(year: 2026, month: 3, day: 7))!,
                    la.date(from: DateComponents(year: 2026, month: 3, day: 8))!,
                    la.date(from: DateComponents(year: 2026, month: 3, day: 9))!]
            .map { la.startOfDay(for: $0) }

        let observations = days.map {
            ImportObservation(day: $0, field: .flow, value: .flow(.medium), recordID: UUID(),
                              sourceBundleID: gpApps, sourceName: "Period Tracker", recordedAt: $0)
        }
        let decisions = ImportReconciler.plan(
            observations: observations, currentValue: { _, _ in nil }, ledger: ledger,
            ownBundleID: caelyn, acceptOwnSource: true, calendar: la, today: today
        )
        ImportReconciler.commit(decisions, into: context, ledger: ledger, batchID: UUID(), calendar: la)

        let keys = entries().map { ImportLedger.dayKey($0.date, calendar: la) }.sorted()
        XCTAssertEqual(keys, ["2026-03-07", "2026-03-08", "2026-03-09"],
                       "the short day is still exactly one day")
    }

    // MARK: - Nothing to import

    func testPeriodTrackerAbsentFromHealthIsACalmEmptyResult() {
        // Only other apps have written anything.
        let summary = importing(otherAppsDataset())
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.daysAffected, 0)
        XCTAssertEqual(entries().count, 0)

        var plan = HealthSyncService.Plan()
        plan.summary = summary
        let preview = ImportPreview.fromHealth(plan, sourceFilter: .periodTrackerGPApps)
        XCTAssertFalse(preview.hasChanges)
        XCTAssertEqual(preview.headline, "Nothing new to bring over")
    }

    func testPeriodTrackerPresentButWritingOnlyUnsupportedTypesIsAlsoCalm() {
        // A type Caelyn has no field for produces no observation at all.
        let summary = importing([])
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(entries().count, 0)
    }

    func testTheEmptyStateNeverTellsHerToGoEnableSomething() {
        var plan = HealthSyncService.Plan()
        plan.unreadableTypes = ["HKCategoryTypeIdentifierCervicalMucusQuality"]
        let preview = ImportPreview.fromHealth(plan, sourceFilter: .periodTrackerGPApps)
        let text = ([preview.headline, preview.sourceLine, preview.safetyLine] + preview.caveats)
            .joined(separator: " ")
        for banned in ["enable", "Settings", "denied", "permission", "HKCategory", "grant"] {
            XCTAssertFalse(text.lowercased().contains(banned.lowercased()),
                           "'\(banned)' has no place in what she reads")
        }
    }

    func testThePreviewNamesPeriodTrackerRatherThanAppleHealth() {
        var plan = HealthSyncService.Plan()
        plan.summary.filled = 4
        plan.summary.daysAffected = 4
        plan.summary.byField = ["flow": 4]
        let preview = ImportPreview.fromHealth(plan, sourceFilter: .periodTrackerGPApps)
        XCTAssertTrue(preview.sourceLine.contains("Period Tracker"))
        XCTAssertTrue(preview.breakdown.contains("4 period days"))
    }
}
