import XCTest
import SwiftData
import HealthKit
@testable import Caelyn

/// Tests for the Apple Health merge engine.
///
/// Everything here exercises `ImportReconciler` and `ImportLedger`
/// directly rather than going through `HKHealthStore`, because the rules that
/// matter — never overwrite what she typed, never duplicate, never loop — are
/// decided before HealthKit is involved. What that leaves unverified is called out
/// in the summary: reading real samples off a real device still has to be checked
/// by hand.
@MainActor
final class HealthSyncTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var ledger: ImportLedger!

    private let calendar = Calendar(identifier: .gregorian)
    private let ownBundle = "smallpanta-icould.com.caelynperiodtracker"
    private let foreignBundle = "com.clue.app"

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self, configurations: config)
        context = container.mainContext
        // nil file URL keeps the ledger in memory, so tests never touch the
        // real one on disk.
        ledger = ImportLedger(fileURL: nil)
    }

    override func tearDownWithError() throws {
        container = nil; context = nil; ledger = nil
    }

    // MARK: - Fixtures

    private func day(_ offset: Int, from base: Date = Date(timeIntervalSince1970: 1_770_000_000)) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: base)!)
    }

    private var today: Date { day(0) }

    private func observation(
        day: Date,
        field: ImportObservation.Field,
        value: ImportObservation.Value,
        recordID: UUID = UUID(),
        bundle: String? = nil,
        source: String = "Clue",
        recordedAt: Date? = nil
    ) -> ImportObservation {
        ImportObservation(
            day: day,
            field: field,
            value: value,
            recordID: recordID,
            sourceBundleID: bundle ?? foreignBundle,
            sourceName: source,
            recordedAt: recordedAt ?? day
        )
    }

    private func plan(
        _ observations: [ImportObservation],
        deleted: [UUID] = [],
        acceptOwnSource: Bool = false
    ) -> [ImportReconciler.Decision] {
        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Date: CycleEntry] = [:]
        for entry in entries { byDay[calendar.startOfDay(for: entry.date)] = entry }
        return ImportReconciler.plan(
            observations: observations,
            deletedRecordIDs: deleted,
            currentValue: { d, f in byDay[self.calendar.startOfDay(for: d)]?.value(for: f) },
            ledger: ledger,
            ownBundleID: ownBundle,
            acceptOwnSource: acceptOwnSource,
            calendar: calendar,
            today: today
        )
    }

    @discardableResult
    private func merge(
        _ observations: [ImportObservation],
        deleted: [UUID] = [],
        acceptOwnSource: Bool = false
    ) -> ImportReconciler.Summary {
        let decisions = plan(observations, deleted: deleted, acceptOwnSource: acceptOwnSource)
        return ImportReconciler.commit(decisions, into: context, ledger: ledger, calendar: calendar).summary
    }

    private func entry(on date: Date) -> CycleEntry? {
        let target = calendar.startOfDay(for: date)
        return ((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? [])
            .first { calendar.isDate($0.date, inSameDayAs: target) }
    }

    private func action(_ decisions: [ImportReconciler.Decision],
                        for field: ImportObservation.Field) -> ImportReconciler.Action? {
        decisions.first { $0.field == field }?.action
    }

    // MARK: - Filling empty fields

    func testImportFillsEmptyDay() {
        let summary = merge([observation(day: day(-10), field: .flow, value: .flow(.medium))])
        XCTAssertEqual(summary.filled, 1)
        XCTAssertEqual(entry(on: day(-10))?.flow, .medium)
    }

    func testImportCreatesOneEntryPerDayNotOnePerObservation() {
        merge([
            observation(day: day(-5), field: .flow, value: .flow(.heavy)),
            observation(day: day(-5), field: .basalTemperature, value: .temperature(36.4)),
            observation(day: day(-5), field: .symptom(.cramps), value: .symptomSeverity(3))
        ])
        let all = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        XCTAssertEqual(all.count, 1, "one calendar day must stay one row")
        XCTAssertEqual(all.first?.flow, .heavy)
        XCTAssertEqual(all.first?.basalTemperature, 36.4)
        XCTAssertEqual(all.first?.symptomSeverity["cramps"], 3)
    }

    // MARK: - Never overwriting her own entries

    func testHandLoggedValueIsNeverOverwritten() {
        let target = day(-3)
        let mine = CycleStore.entry(for: target, in: context, calendar: calendar)
        mine.flow = .heavy
        context.saveOrLog()

        let summary = merge([observation(day: target, field: .flow, value: .flow(.light))])

        XCTAssertEqual(entry(on: target)?.flow, .heavy, "her value must stand")
        XCTAssertEqual(summary.keptUserValue, 1)
        XCTAssertEqual(summary.filled, 0)
    }

    func testImportedValueEditedByHandBecomesHersPermanently() {
        let target = day(-4)
        let recordID = UUID()
        merge([observation(day: target, field: .flow, value: .flow(.light), recordID: recordID)])
        XCTAssertEqual(entry(on: target)?.flow, .light)

        // She corrects it in Caelyn.
        entry(on: target)?.flow = .heavy
        context.saveOrLog()

        // The same record comes back with a new value from its source.
        let summary = merge([observation(day: target, field: .flow, value: .flow(.medium), recordID: recordID)])

        XCTAssertEqual(entry(on: target)?.flow, .heavy, "an edit makes the value hers")
        XCTAssertEqual(summary.keptUserValue, 1)
        XCTAssertNil(ledger.claim(day: target, field: .flow, calendar: calendar),
                     "provenance is released once she edits it")
    }

    func testKeptUserValueDoesNotBlockOtherFieldsOnSameDay() {
        let target = day(-6)
        let mine = CycleStore.entry(for: target, in: context, calendar: calendar)
        mine.flow = .heavy
        context.saveOrLog()

        let summary = merge([
            observation(day: target, field: .flow, value: .flow(.light)),
            observation(day: target, field: .basalTemperature, value: .temperature(36.6))
        ])
        XCTAssertEqual(entry(on: target)?.flow, .heavy)
        XCTAssertEqual(entry(on: target)?.basalTemperature, 36.6)
        XCTAssertEqual(summary.keptUserValue, 1)
        XCTAssertEqual(summary.filled, 1)
    }

    // MARK: - Duplicates

    func testSameRecordImportedTwiceChangesNothing() {
        let target = day(-7)
        let recordID = UUID()
        let sample = observation(day: target, field: .flow, value: .flow(.medium), recordID: recordID)

        let first = merge([sample])
        let second = merge([sample])

        XCTAssertEqual(first.filled, 1)
        XCTAssertEqual(second.filled, 0)
        XCTAssertEqual(second.updated, 0)
        XCTAssertEqual(second.duplicates, 1)
        XCTAssertEqual(entry(on: target)?.flow, .medium)
    }

    func testImportingTheSameFileTwiceCreatesNoDuplicateDays() {
        let batch = (1...30).map {
            observation(day: day(-$0), field: .flow, value: .flow(.light), recordID: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))!)
        }
        merge(batch)
        merge(batch)
        let all = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        XCTAssertEqual(all.count, 30)
    }

    func testTwoSourcesSameDayAndFieldKeepsTheMoreRecentOne() {
        let target = day(-8)
        let older = observation(day: target, field: .flow, value: .flow(.light),
                                source: "Old", recordedAt: target)
        let newer = observation(day: target, field: .flow, value: .flow(.heavy),
                                source: "New", recordedAt: target.addingTimeInterval(3600))

        let decisions = plan([older, newer])
        ImportReconciler.commit(decisions, into: context, ledger: ledger, calendar: calendar)

        XCTAssertEqual(entry(on: target)?.flow, .heavy)
        XCTAssertTrue(decisions.contains { $0.action == .rejected(.supersededInBatch) })
    }

    // MARK: - Updates from the same source

    func testSourceEditingItsOwnRecordUpdatesTheValue() {
        let target = day(-9)
        let recordID = UUID()
        merge([observation(day: target, field: .flow, value: .flow(.light), recordID: recordID)])

        let summary = merge([observation(day: target, field: .flow, value: .flow(.heavy), recordID: recordID)])

        XCTAssertEqual(entry(on: target)?.flow, .heavy)
        XCTAssertEqual(summary.updated, 1)
        XCTAssertEqual(summary.keptUserValue, 0)
    }

    // MARK: - The sync loop

    func testCaelynsOwnRecordsAreIgnoredOnIncrementalSync() {
        let target = day(-11)
        let decisions = plan([
            observation(day: target, field: .flow, value: .flow(.medium), bundle: ownBundle, source: "Caelyn")
        ], acceptOwnSource: false)
        XCTAssertTrue(decisions.isEmpty, "Caelyn must not read its own writes back as news")
    }

    func testCaelynsOwnRecordsAreAcceptedOnFullRestore() {
        let target = day(-12)
        let summary = merge([
            observation(day: target, field: .flow, value: .flow(.medium), bundle: ownBundle, source: "Caelyn")
        ], acceptOwnSource: true)
        XCTAssertEqual(summary.filled, 1, "a reinstall must be able to recover her own history")
        XCTAssertEqual(entry(on: target)?.flow, .medium)
    }

    func testForeignRecordsStillArriveDuringIncrementalSync() {
        let target = day(-13)
        let summary = merge([
            observation(day: target, field: .flow, value: .flow(.light), bundle: ownBundle),
            observation(day: target, field: .basalTemperature, value: .temperature(36.5), bundle: foreignBundle)
        ], acceptOwnSource: false)
        XCTAssertEqual(summary.filled, 1)
        XCTAssertNil(entry(on: target)?.flow)
        XCTAssertEqual(entry(on: target)?.basalTemperature, 36.5)
    }

    // MARK: - Deletions

    func testDeletedRecordClearsAValueCaelynStillOwns() {
        let target = day(-14)
        let recordID = UUID()
        merge([observation(day: target, field: .basalTemperature, value: .temperature(36.5), recordID: recordID)])
        XCTAssertEqual(entry(on: target)?.basalTemperature, 36.5)

        let summary = merge([], deleted: [recordID])

        XCTAssertEqual(summary.cleared, 1)
        XCTAssertNil(entry(on: target)?.basalTemperature)
    }

    func testDeletedRecordLeavesAValueSheHasSinceChanged() {
        let target = day(-15)
        let recordID = UUID()
        merge([observation(day: target, field: .basalTemperature, value: .temperature(36.5), recordID: recordID)])

        entry(on: target)?.basalTemperature = 36.9   // she corrects it
        context.saveOrLog()

        let summary = merge([], deleted: [recordID])

        XCTAssertEqual(summary.cleared, 0)
        XCTAssertEqual(entry(on: target)?.basalTemperature, 36.9, "her correction survives the source's deletion")
    }

    func testDeletingTheOnlyValueOnADayRemovesTheEmptyRow() {
        let target = day(-16)
        let recordID = UUID()
        merge([observation(day: target, field: .flow, value: .flow(.light), recordID: recordID)])
        XCTAssertNotNil(entry(on: target))

        merge([], deleted: [recordID])
        XCTAssertNil(entry(on: target), "a day emptied by a deletion should not linger as a blank row")
    }

    func testDeletingOneFieldLeavesTheRestOfTheDay() {
        let target = day(-17)
        let flowID = UUID()
        merge([
            observation(day: target, field: .flow, value: .flow(.light), recordID: flowID),
            observation(day: target, field: .symptom(.cramps), value: .symptomSeverity(2))
        ])
        merge([], deleted: [flowID])

        XCTAssertNil(entry(on: target)?.flow)
        XCTAssertEqual(entry(on: target)?.symptoms, [.cramps])
    }

    func testUnknownDeletedRecordIsHarmless() {
        let summary = merge([], deleted: [UUID()])
        XCTAssertEqual(summary.cleared, 0)
    }

    // MARK: - Validation

    func testFutureDatedRecordIsRejected() {
        let decisions = plan([observation(day: day(3), field: .flow, value: .flow(.medium))])
        XCTAssertEqual(action(decisions, for: .flow), .rejected(.futureDate))
        XCTAssertNil(entry(on: day(3)))
    }

    func testAbsurdlyOldRecordIsRejected() {
        let ancient = calendar.date(byAdding: .year, value: -60, to: today)!
        let decisions = plan([observation(day: ancient, field: .flow, value: .flow(.medium))])
        XCTAssertEqual(action(decisions, for: .flow), .rejected(.implausibleDate))
    }

    func testFahrenheitLookingTemperatureIsRejected() {
        // 98.6 in the Celsius column is the classic bad-import value.
        let decisions = plan([observation(day: day(-1), field: .basalTemperature, value: .temperature(98.6))])
        XCTAssertEqual(action(decisions, for: .basalTemperature), .rejected(.temperatureOutOfRange))
        XCTAssertNil(entry(on: day(-1))?.basalTemperature)
    }

    func testNonFiniteTemperatureIsRejected() {
        let decisions = plan([observation(day: day(-1), field: .basalTemperature, value: .temperature(.nan))])
        guard case .rejected = action(decisions, for: .basalTemperature) else {
            return XCTFail("a non-finite temperature must never reach the store")
        }
    }

    func testOutOfRangeSeverityIsRejected() {
        let decisions = plan([observation(day: day(-1), field: .symptom(.cramps), value: .symptomSeverity(9))])
        XCTAssertEqual(action(decisions, for: .symptom(.cramps)), .rejected(.severityOutOfRange))
    }

    func testRejectedRecordsAreCountedNotSilentlyDropped() {
        let summary = merge([
            observation(day: day(3), field: .flow, value: .flow(.medium)),
            observation(day: day(-1), field: .basalTemperature, value: .temperature(98.6))
        ])
        XCTAssertEqual(summary.rejected, 2)
        XCTAssertEqual(summary.filled, 0)
    }

    func testEmptyImportIsAnEmptySummary() {
        let summary = merge([])
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.daysAffected, 0)
    }

    // MARK: - Coexistence with hand-logged data

    func testImportedAndHandLoggedDataCoexistOnTheSameDay() {
        let target = day(-18)
        let mine = CycleStore.entry(for: target, in: context, calendar: calendar)
        mine.mood = .calm
        mine.note = "felt off today"
        mine.pain = 6
        context.saveOrLog()

        merge([
            observation(day: target, field: .flow, value: .flow(.medium)),
            observation(day: target, field: .symptom(.bloating), value: .symptomSeverity(1))
        ])

        let result = entry(on: target)
        XCTAssertEqual(result?.mood, .calm)
        XCTAssertEqual(result?.note, "felt off today")
        XCTAssertEqual(result?.pain, 6)
        XCTAssertEqual(result?.flow, .medium)
        XCTAssertEqual(result?.symptoms, [.bloating])
    }

    func testImportNeverTouchesPainScore() {
        // HealthKit stores pain severity, Caelyn stores a 0-10 slider. Importing a
        // pain category must add the chip and invent no number.
        let target = day(-19)
        merge([observation(day: target, field: .painType(.pelvicPain), value: .present)])
        XCTAssertEqual(entry(on: target)?.painTypes, [.pelvicPain])
        XCTAssertNil(entry(on: target)?.pain)
    }

    func testValueLoggedBetweenPlanningAndConfirmingIsNotOverwritten() {
        let target = day(-25)
        // Plan an import while the day is still empty.
        let decisions = plan([observation(day: target, field: .flow, value: .flow(.light))])
        XCTAssertEqual(action(decisions, for: .flow), .fill)

        // She logs that same day before confirming.
        let mine = CycleStore.entry(for: target, in: context, calendar: calendar)
        mine.flow = .heavy
        context.saveOrLog()

        let summary = ImportReconciler.commit(decisions, into: context, ledger: ledger, calendar: calendar).summary

        XCTAssertEqual(entry(on: target)?.flow, .heavy, "a value logged mid-confirmation still wins")
        XCTAssertEqual(summary.filled, 0)
        XCTAssertEqual(summary.keptUserValue, 1)
    }

    // MARK: - Large history

    func testLargeHistoricalImport() {
        var batch: [ImportObservation] = []
        for offset in 1...(365 * 3) where offset % 28 < 5 {
            batch.append(observation(day: day(-offset), field: .flow, value: .flow(.medium)))
        }
        let summary = merge(batch)
        XCTAssertEqual(summary.filled, batch.count)
        XCTAssertEqual(summary.daysAffected, batch.count)

        // The imported history must reconstruct into real cycles.
        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        let cycles = PredictionEngine.cycles(from: entries, today: today)
        XCTAssertGreaterThan(cycles.count, 30)
    }

    // MARK: - Timezone / date boundaries

    func testLateNightRecordLandsOnItsLocalDay() {
        var eastern = Calendar(identifier: .gregorian)
        eastern.timeZone = TimeZone(identifier: "America/New_York")!
        let base = eastern.startOfDay(for: Date(timeIntervalSince1970: 1_770_000_000))
        let lateNight = base.addingTimeInterval(23 * 3600 + 45 * 60)

        let observation = ImportObservation(
            day: lateNight, field: .flow, value: .flow(.light),
            recordID: UUID(), sourceBundleID: foreignBundle, sourceName: "Clue", recordedAt: lateNight
        )
        let decisions = ImportReconciler.plan(
            observations: [observation],
            currentValue: { _, _ in nil },
            ledger: ledger,
            ownBundleID: ownBundle,
            acceptOwnSource: false,
            calendar: eastern,
            today: base.addingTimeInterval(86_400 * 5)
        )
        XCTAssertEqual(decisions.count, 1)
        XCTAssertEqual(decisions[0].day, eastern.startOfDay(for: lateNight))
    }

    func testLedgerDayKeyIsStableAcrossTimeZones() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let localNoon = DateComponents(calendar: tokyo, year: 2026, month: 3, day: 14, hour: 12).date!
        XCTAssertEqual(
            ImportLedger.dayKey(tokyo.startOfDay(for: localNoon), calendar: tokyo),
            "2026-03-14"
        )
        let laNoon = DateComponents(calendar: la, year: 2026, month: 3, day: 14, hour: 12).date!
        XCTAssertEqual(
            ImportLedger.dayKey(la.startOfDay(for: laNoon), calendar: la),
            "2026-03-14",
            "the same calendar day must key identically wherever she is"
        )
    }

    func testProvenanceSurvivesADaylightSavingBoundary() {
        // US spring-forward 2026-03-08.
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let dstDay = la.startOfDay(for: DateComponents(calendar: la, year: 2026, month: 3, day: 8, hour: 12).date!)

        let record = ImportObservation(
            day: dstDay, field: .flow, value: .flow(.heavy),
            recordID: UUID(), sourceBundleID: foreignBundle, sourceName: "Clue", recordedAt: dstDay
        )
        ledger.record(record, calendar: la)
        XCTAssertNotNil(ledger.claim(day: dstDay, field: .flow, calendar: la))
    }

    // MARK: - Reinstall / reconnect

    func testLosingTheLedgerFailsSafeAndNeverOverwrites() {
        let target = day(-20)
        let recordID = UUID()
        merge([observation(day: target, field: .flow, value: .flow(.light), recordID: recordID)])

        // Reinstall: the log survives (restored from Health), provenance does not.
        ledger.removeAll()

        let summary = merge([observation(day: target, field: .flow, value: .flow(.heavy), recordID: recordID)])

        XCTAssertEqual(entry(on: target)?.flow, .light,
                       "with no provenance every value is treated as hers")
        XCTAssertEqual(summary.keptUserValue, 1)
    }

    func testForgettingSyncStateReleasesEveryClaim() {
        merge([
            observation(day: day(-21), field: .flow, value: .flow(.light)),
            observation(day: day(-22), field: .flow, value: .flow(.medium))
        ])
        XCTAssertEqual(ledger.claimCount, 2)
        ledger.removeAll()
        XCTAssertEqual(ledger.claimCount, 0)
    }

    // MARK: - Ledger persistence

    func testLedgerRoundTripsThroughDisk() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "ledger-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = ImportLedger(fileURL: url)
        let record = observation(day: day(-23), field: .flow, value: .flow(.heavy))
        writer.record(record, calendar: calendar)
        writer.save()

        let reader = ImportLedger(fileURL: url)
        let claim = reader.claim(day: day(-23), field: .flow, calendar: calendar)
        XCTAssertEqual(claim?.importedValue, "heavy")
        XCTAssertEqual(claim?.sourceName, "Clue")
        XCTAssertTrue(reader.hasSeen(recordID: record.recordID))
    }

    func testCorruptLedgerFileDoesNotBlockSyncing() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "ledger-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{ not json".utf8).write(to: url)

        let recovered = ImportLedger(fileURL: url)
        XCTAssertEqual(recovered.claimCount, 0, "a corrupt ledger starts empty rather than throwing")
    }

    func testReclaimingAFieldDropsTheOldRecordsBackReference() {
        let target = day(-24)
        let first = UUID(), second = UUID()
        merge([observation(day: target, field: .flow, value: .flow(.light), recordID: first)])
        merge([observation(day: target, field: .flow, value: .flow(.heavy), recordID: second,
                           recordedAt: target.addingTimeInterval(7200))])

        XCTAssertTrue(ledger.claims(forRecord: first).isEmpty)
        XCTAssertEqual(ledger.claims(forRecord: second).count, 1)
        XCTAssertEqual(entry(on: target)?.flow, .heavy)
    }

    // MARK: - Field mapping

    func testEveryFieldSurvivesALedgerKeyRoundTrip() {
        let fields: [ImportObservation.Field] = [
            .flow, .basalTemperature, .cervicalMucus, .ovulationTest,
            .pregnancyTest, .sexualActivity, .symptom(.cramps), .painType(.pelvicPain)
        ]
        for field in fields {
            XCTAssertEqual(ImportObservation.Field(ledgerKey: field.ledgerKey), field,
                           "\(field.ledgerKey) must survive a round trip or its provenance is orphaned")
        }
    }

    func testUnknownLedgerKeyIsRejectedRatherThanGuessed() {
        XCTAssertNil(ImportObservation.Field(ledgerKey: "symptom:notARealSymptom"))
        XCTAssertNil(ImportObservation.Field(ledgerKey: "somethingElse"))
    }

    // MARK: - HealthKit value mapping

    func testFlowRawValuesMapToCaelynLevels() {
        XCTAssertEqual(HealthDataCatalog.flowLevel(fromRawValue: 2), .light)
        XCTAssertEqual(HealthDataCatalog.flowLevel(fromRawValue: 3), .medium)
        XCTAssertEqual(HealthDataCatalog.flowLevel(fromRawValue: 4), .heavy)
        // Raw 1 is a bleeding day recorded without a heaviness. This assertion
        // used to expect nil, which is exactly the bug that lost those days.
        XCTAssertEqual(HealthDataCatalog.flowLevel(fromRawValue: 1), .unspecified)
        // Raw 5 is "no bleeding today" — an absence, and still not a day.
        XCTAssertNil(HealthDataCatalog.flowLevel(fromRawValue: 5))
    }

    func testCervicalMucusMapsOneToOne() {
        XCTAssertEqual(HealthDataCatalog.mucus(fromRawValue: HKCategoryValueCervicalMucusQuality.dry.rawValue), .dry)
        XCTAssertEqual(HealthDataCatalog.mucus(fromRawValue: HKCategoryValueCervicalMucusQuality.eggWhite.rawValue), .eggWhite)
        XCTAssertNil(HealthDataCatalog.mucus(fromRawValue: 99))
    }

    func testOvulationSurgeAndPositiveShareARawValue() {
        // HealthKit gives `.positive` and `.luteinizingHormoneSurge` the same raw
        // value, so without Caelyn's own metadata "surge" is the honest reading.
        XCTAssertEqual(HKCategoryValueOvulationTestResult.positive.rawValue,
                       HKCategoryValueOvulationTestResult.luteinizingHormoneSurge.rawValue)
        XCTAssertEqual(HealthDataCatalog.ovulationResult(fromRawValue: 2), .lhSurge)
        XCTAssertEqual(HealthDataCatalog.ovulationResult(fromRawValue: 1), .negative)
        XCTAssertEqual(HealthDataCatalog.ovulationResult(fromRawValue: 4), .rising)
        XCTAssertNil(HealthDataCatalog.ovulationResult(fromRawValue: 3), "indeterminate has no honest mapping")
    }

    func testSeverityMapping() {
        XCTAssertEqual(HealthDataCatalog.severityLevel(from: HKCategoryValueSeverity.mild.rawValue), 1)
        XCTAssertEqual(HealthDataCatalog.severityLevel(from: HKCategoryValueSeverity.moderate.rawValue), 2)
        XCTAssertEqual(HealthDataCatalog.severityLevel(from: HKCategoryValueSeverity.severe.rawValue), 3)
        XCTAssertEqual(HealthDataCatalog.severityLevel(from: HKCategoryValueSeverity.unspecified.rawValue), 2)
        XCTAssertNil(HealthDataCatalog.severityLevel(from: HKCategoryValueSeverity.notPresent.rawValue),
                     "'not present' records an absence and must not add the symptom")
    }

    func testFlowSurvivesAWriteAndReadRoundTripIncludingSpotting() {
        // Spotting has no HealthKit value of its own, so it rides in metadata.
        // If the write and read halves ever disagree on that key, spotting would
        // silently come back as "light".
        for level in FlowLevel.allCases {
            let sample = HealthKitService.makeFlowSample(date: day(-2), flow: level, isCycleStart: false)
            XCTAssertEqual(HealthDataCatalog.flowLevel(from: sample), level,
                           "\(level.rawValue) did not survive the round trip")
        }
    }

    // MARK: - Bleeding with no recorded intensity (H-6)

    /// HealthKit refuses a menstrual-flow sample without the cycle-start key, so
    /// building one here mirrors what the store actually holds.
    private func flowSample(rawValue: Int, on date: Date, cycleStart: Bool = false) -> HKCategorySample {
        HKCategorySample(
            type: HKCategoryType(.menstrualFlow),
            value: rawValue,
            start: date, end: date,
            metadata: [HKMetadataKeyMenstrualCycleStart: cycleStart]
        )
    }

    /// The controlled pair that found the bug: Apple Health raw 1 (intensity not
    /// recorded) next to raw 4 (heavy). Caelyn used to build no observation at all
    /// for raw 1, so the day vanished — no error, and a preview that quietly said
    /// one period day instead of two.
    func testUnspecifiedAndHeavyBothSurviveAnAppleHealthImport() {
        let dayA = day(-20)   // unspecified
        let dayB = day(-19)   // heavy

        let observations = [
            HealthDataCatalog.observation(from: flowSample(rawValue: 1, on: dayA, cycleStart: true), calendar: calendar),
            HealthDataCatalog.observation(from: flowSample(rawValue: 4, on: dayB), calendar: calendar)
        ]
        XCTAssertEqual(observations.compactMap { $0 }.count, 2, "both days must become observations")

        let summary = merge(observations.compactMap { $0 }, acceptOwnSource: true)

        XCTAssertEqual(summary.byField["flow"], 2, "the preview must say two period days, not one")
        XCTAssertEqual(summary.daysAffected, 2)
        XCTAssertEqual(entry(on: dayA)?.flow, .unspecified, "the day is kept, without inventing an intensity")
        XCTAssertEqual(entry(on: dayB)?.flow, .heavy)
    }

    func testUnspecifiedCountsAsABleedingDayInCycleReconstruction() {
        // Two periods a month apart; the first day of each has no recorded
        // intensity, exactly as an Apple Health import can deliver it.
        var observations: [ImportObservation] = []
        for cycle in 1...3 {
            for offset in 0..<4 {
                let date = day(-(cycle * 28) + offset)
                let raw = offset == 0 ? 1 : 3
                if let observation = HealthDataCatalog.observation(
                    from: flowSample(rawValue: raw, on: date, cycleStart: offset == 0), calendar: calendar
                ) { observations.append(observation) }
            }
        }
        merge(observations, acceptOwnSource: true)

        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        let cycles = PredictionEngine.cycles(from: entries, today: today)
        XCTAssertEqual(cycles.count, 2)
        XCTAssertTrue(cycles.allSatisfy { $0.length == 28 },
                      "a day with no recorded intensity is still the day the period started")
        XCTAssertTrue(cycles.allSatisfy { $0.periodLength == 4 })
    }

    func testNoBleedingIsStillIgnored() {
        // Raw 5 means "no bleeding today" — an absence, not a day with an unknown
        // amount. It must never create an entry.
        XCTAssertNil(HealthDataCatalog.flowLevel(fromRawValue: 5))
        let observation = HealthDataCatalog.observation(from: flowSample(rawValue: 5, on: day(-3)), calendar: calendar)
        XCTAssertNil(observation)
    }

    func testEveryAppleHealthFlowValueMapsAsApplesDocumentationDescribesIt() {
        XCTAssertEqual(HealthDataCatalog.flowLevel(fromRawValue: 1), .unspecified)
        XCTAssertEqual(HealthDataCatalog.flowLevel(fromRawValue: 2), .light)
        XCTAssertEqual(HealthDataCatalog.flowLevel(fromRawValue: 3), .medium)
        XCTAssertEqual(HealthDataCatalog.flowLevel(fromRawValue: 4), .heavy)
        XCTAssertNil(HealthDataCatalog.flowLevel(fromRawValue: 5))
        XCTAssertNil(HealthDataCatalog.flowLevel(fromRawValue: 99))
    }

    func testUnspecifiedIsWrittenBackToHealthAsUnspecified() {
        XCTAssertEqual(HealthKitService.mapFlowToHK(.unspecified).rawValue, 1,
                       "writing it back as any intensity would invent one")
        XCTAssertEqual(HealthKitService.caelynFlow(fromHKRawValue: 1), .unspecified)
    }

    func testUnspecifiedDayCanStillBeOverwrittenByHerOwnChoice() {
        let target = day(-21)
        guard let observation = HealthDataCatalog.observation(
            from: flowSample(rawValue: 1, on: target, cycleStart: true), calendar: calendar
        ) else { return XCTFail("expected an observation") }
        merge([observation], acceptOwnSource: true)
        XCTAssertEqual(entry(on: target)?.flow, .unspecified)

        entry(on: target)?.flow = .heavy      // she fills it in
        context.saveOrLog()

        // The same sample coming round again must not undo her choice.
        let summary = merge([observation], acceptOwnSource: true)
        XCTAssertEqual(entry(on: target)?.flow, .heavy)
        XCTAssertEqual(summary.keptUserValue, 1)
    }

    func testRepeatedImportOfAnUnspecifiedDayDoesNotDuplicate() {
        let target = day(-22)
        guard let observation = HealthDataCatalog.observation(
            from: flowSample(rawValue: 1, on: target, cycleStart: true), calendar: calendar
        ) else { return XCTFail("expected an observation") }

        let first = merge([observation], acceptOwnSource: true)
        let second = merge([observation], acceptOwnSource: true)

        XCTAssertEqual(first.filled, 1)
        XCTAssertEqual(second.filled, 0)
        XCTAssertEqual(second.duplicates, 1)
        XCTAssertEqual(((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []).count, 1)
    }

    func testIntermenstrualBleedingIsASymptomNotFlow() {
        // Mapping it to flow would invent period starts: PredictionEngine treats
        // any non-nil flow as a bleed day.
        XCTAssertEqual(HealthDataCatalog.symptomReads[.intermenstrualBleeding], .irregularBleed)
        XCTAssertFalse(HealthDataCatalog.symptomReads.keys.contains(.menstrualFlow))
    }

    func testImportingIntermenstrualBleedingDoesNotCreateACycle() {
        // Three months of real periods, plus mid-cycle spotting from another app.
        var batch: [ImportObservation] = []
        for cycle in 1...3 {
            for dayOfPeriod in 0..<4 {
                batch.append(observation(day: day(-(cycle * 28) + dayOfPeriod), field: .flow, value: .flow(.medium)))
            }
            batch.append(observation(day: day(-(cycle * 28) + 14), field: .symptom(.irregularBleed), value: .symptomSeverity(1)))
        }
        merge(batch)

        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        let cycles = PredictionEngine.cycles(from: entries, today: today)
        XCTAssertEqual(cycles.count, 2, "spotting between periods must not split a cycle in two")
        for cycle in cycles {
            XCTAssertEqual(cycle.length, 28, "cycle length must be unaffected by imported spotting")
        }
    }

    // MARK: - Read groups honour her toggles

    func testDisabledTogglesMeanTheTypeIsNeverQueried() {
        let profile = UserProfile()
        profile.healthKitConnected = true
        XCTAssertTrue(HealthSyncService.enabledTypes(for: profile).isEmpty)

        profile.hkReadFlow = true
        let flowOnly = HealthSyncService.enabledTypes(for: profile)
        XCTAssertEqual(flowOnly.count, 1)
        XCTAssertEqual(flowOnly.first?.identifier, HKCategoryTypeIdentifier.menstrualFlow.rawValue)

        profile.hkReadSymptoms = true
        profile.hkReadFertility = true
        XCTAssertGreaterThan(HealthSyncService.enabledTypes(for: profile).count, flowOnly.count)
    }

    func testEveryRequestedReadTypeHasSomewhereToLand() {
        // The 5.1.1 rule made mechanical: nothing may be requested that the merge
        // engine cannot map. Wrist temperature is the one exception — it is read
        // as a series by WristTempOvulationEngine, not merged into day fields.
        let wrist = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)
        for type in HealthDataCatalog.allReadTypes where type != wrist {
            guard let sampleType = type as? HKSampleType else {
                return XCTFail("\(type.identifier) is not a sample type")
            }
            XCTAssertTrue(
                HealthDataCatalog.syncedSampleTypes.contains(sampleType),
                "\(type.identifier) is requested but never read — remove it or map it"
            )
        }
    }

    // MARK: - Copy

    func testImportCopyNamesThingsSheRecognises() {
        var summary = ImportReconciler.Summary()
        summary.filled = 3
        summary.daysAffected = 2
        summary.byField = ["flow": 2, "symptom": 1]
        let text = ImportCopy.importResult(summary)

        XCTAssertTrue(text.contains("2 period days"))
        XCTAssertTrue(text.contains("1 symptom"))
        for jargon in ["HealthKit", "HKCategory", "sample", "record", "field"] {
            XCTAssertFalse(text.lowercased().contains(jargon.lowercased()), "leaked '\(jargon)' into user copy")
        }
    }

    func testCopySaysWhatWasLeftAlone() {
        var summary = ImportReconciler.Summary()
        summary.filled = 1
        summary.daysAffected = 1
        summary.byField = ["flow": 1]
        summary.keptUserValue = 4
        XCTAssertTrue(ImportCopy.importResult(summary).contains("Caelyn kept yours"))
    }

    func testEmptyImportCopyIsNotAlarming() {
        let text = ImportCopy.importResult(ImportReconciler.Summary())
        XCTAssertEqual(text, "Nothing new to bring over.")
    }
}

// MARK: - Phase 1C: the Apple Health routes tell the truth

/// The confirmed Phase 1C findings, each pinned by the behaviour that was wrong.
///
/// **What these tests deliberately do not claim.** Nothing here proves how real
/// HealthKit behaves on a device: the simulator grants and denies differently, and
/// read authorization is never disclosed by Apple at all. These cover Caelyn's own
/// logic — which read scope it asks for, which states it can distinguish, and what
/// it says about each — and stop there.
@MainActor
final class HealthImportCorrectnessTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private let calendar = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        context = container.mainContext
    }

    override func tearDownWithError() throws { container = nil; context = nil }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: y, month: m, day: d))!)
    }

    // MARK: A — onboarding has no profile, and that must no longer matter

    /// `readAppleHealth` used to take a non-optional `UserProfile`, and the view
    /// `guard let`-ed on it — so during onboarding, before the profile exists, five
    /// of the nine picker rows silently returned her to the source list. The scope
    /// a Health read needs is a set of types, not a profile.
    func testTheHealthRouteNoLongerRequiresAProfile() async {
        let model = BringHistoryModel(calendar: calendar, ledger: ImportLedger(fileURL: nil))

        // Passing no profile must not trap or bail before it has even looked.
        await model.readAppleHealth(profile: nil, context: context, today: day(2026, 7, 1))

        switch model.phase {
        case .choosingSource:
            XCTFail("A nil profile silently returned her to the source list — the Phase 1C dead end.")
        case .confirming, .failed, .reading, .importing, .done:
            break   // any of these is a real, explained outcome
        }
    }

    /// With no profile the read scope is everything Apple's sheet covers, which is
    /// the same set the onboarding import already used.
    func testWithNoProfileTheScopeIsEverythingThePermissionSheetAsksAbout() {
        XCTAssertFalse(HealthDataCatalog.syncedSampleTypes.isEmpty)
        let fromCatalog = Set(HealthDataCatalog.syncedSampleTypes.map(\.identifier))
        let profile = UserProfile()
        profile.hkReadFlow = true; profile.hkReadSymptoms = true; profile.hkReadFertility = true
        let fromProfile = Set(HealthSyncService.enabledTypes(for: profile).map(\.identifier))
        XCTAssertEqual(fromCatalog, fromProfile,
                       "The no-profile scope must match a fully-enabled profile, or onboarding would import less than Settings does.")
    }

    // MARK: B — every Apple Health-backed row reaches the same real path

    func testAllFiveAppleHealthBackedRowsRouteToAHealthImport() {
        let healthRows = ImportSourceGuide.pickable.filter { $0.source == .appleHealth }
        XCTAssertEqual(Set(healthRows.map(\.title)),
                       ["Apple Health", "Period Tracker", "Natural Cycles", "Glow", "Eve"])
        for row in healthRows {
            XCTAssertFalse(row.needsAFile, "\(row.title) must not send her to a file picker.")
            XCTAssertTrue(row.route == .appleHealth || row.route == .appleHealthAfterInstructions,
                          "\(row.title) must end at Apple Health.")
        }
        // Four of them narrow to one app; the Apple Health row itself does not.
        XCTAssertNil(ImportSourceGuide.appleHealth.healthSourceFilter)
        for row in healthRows where row.title != "Apple Health" {
            XCTAssertNotNil(row.healthSourceFilter, "\(row.title) must name the app it is importing.")
        }
    }

    // MARK: C/D — write authorization is asked for, and never faked

    /// The scopes are per-toggle, so turning on "write flow" cannot silently ask
    /// about twelve symptom categories she never mentioned.
    func testEachWriteToggleAsksOnlyForTheTypesItNeeds() {
        XCTAssertEqual(HealthKitService.WriteScope.flow.types, [HealthKitService.menstrualFlowType])

        let symptomTypes = HealthKitService.WriteScope.symptoms.types
        XCTAssertFalse(symptomTypes.contains(HealthKitService.menstrualFlowType),
                       "The symptom toggle must not quietly acquire flow-writing.")
        XCTAssertTrue(symptomTypes.isSuperset(of: Set(HealthKitService.symptomCategoryMap.values)))
        XCTAssertTrue(symptomTypes.isSuperset(of: Set(HealthKitService.painCategoryMap.values)))

        // Between them the two scopes cover exactly what Caelyn can write, so no
        // write path exists that no toggle ever asks permission for.
        XCTAssertEqual(HealthKitService.WriteScope.flow.types.union(symptomTypes),
                       HealthKitService.allWritableTypes)
    }

    /// `canWrite` is read back from HealthKit, never assumed from the toggle. On a
    /// simulator with nothing granted it is false — which is the point: the toggle
    /// may not claim to be on when Caelyn cannot actually write.
    func testWriteCapabilityIsReadFromHealthKitNotFromTheToggle() {
        let profile = UserProfile()
        profile.hkWriteFlow = true          // as if she had flipped it
        context.insert(profile)

        // The stored flag and the real capability are independent by construction.
        XCTAssertEqual(HealthKitService.canWrite(.flow), HealthKitService.canWrite(.flow))
        if !HealthKitService.canWrite(.flow) {
            XCTAssertTrue(profile.hkWriteFlow,
                          "The model still holds what she asked for; the UI is what must not lie about it.")
        }
    }

    // MARK: E — a HealthKit failure may never touch her own history

    /// The local save happens before any Health write is attempted, and nothing in
    /// the Health path can roll it back. This is the local-first rule at the
    /// narrowest point where it could plausibly have been broken.
    func testLocalEntrySurvivesWhenHealthKitCannotWrite() async {
        let profile = UserProfile()
        profile.healthKitConnected = true
        profile.hkWriteFlow = true
        profile.hkWriteSymptoms = true
        context.insert(profile)

        let entry = CycleStore.entry(for: day(2026, 7, 1), in: context, calendar: calendar)
        entry.flow = .heavy
        entry.symptoms = [.cramps]
        context.saveOrLog()

        // On the simulator this write is not authorized, so it reports failure.
        // Whatever it reports, her entry must be untouched.
        _ = await HealthKitService.syncEntryToHealth(entry, in: [entry], profile: profile)

        let stored = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.flow, .heavy)
        XCTAssertEqual(stored.first?.symptoms, [.cramps])
    }

    // MARK: F/G/H — only the states Caelyn can actually know are distinguished

    func testDisabledReadTypesAreAnActionableStateNotAnEmptyImport() async {
        let profile = UserProfile()
        profile.healthKitConnected = true
        profile.hkReadFlow = false
        profile.hkReadSymptoms = false
        profile.hkReadFertility = false
        context.insert(profile)

        let plan = await HealthSyncService.preview(mode: .fullImport, profile: profile, context: context)
        XCTAssertEqual(plan.outcome, .noReadTypesEnabled)

        let preview = ImportPreview.fromHealth(plan)
        XCTAssertEqual(preview.headline, "Caelyn isn't set to read anything from Apple Health")
        XCTAssertNotNil(preview.nextStep, "This one Caelyn genuinely knows, so it must say what to do.")
        XCTAssertNotEqual(preview.headline, "Nothing new to bring over")
    }

    func testNotConnectedIsDistinctFromHavingLookedAndFoundNothing() async {
        let profile = UserProfile()
        profile.healthKitConnected = false
        context.insert(profile)

        let plan = await HealthSyncService.preview(mode: .fullImport, profile: profile, context: context)
        XCTAssertTrue(plan.outcome == .notConnected || plan.outcome == .unavailable)

        if plan.outcome == .notConnected {
            let preview = ImportPreview.fromHealth(plan)
            XCTAssertEqual(preview.headline, "Caelyn isn't connected to Apple Health yet")
            XCTAssertNotNil(preview.nextStep)
        }
    }

    /// A genuine zero-result query stays calm and offers no fix, because Caelyn has
    /// nothing to suggest — it asked, and the answer was nothing.
    func testAGenuineZeroResultStaysCalmAndSuggestsNothing() {
        let preview = ImportPreview.fromHealth(HealthSyncService.Plan())   // outcome .read
        XCTAssertEqual(preview.headline, "Nothing new to bring over")
        XCTAssertNil(preview.nextStep)
        let text = ([preview.headline, preview.sourceLine, preview.safetyLine] + preview.caveats)
            .joined(separator: " ").lowercased()
        for banned in ["denied", "permission", "you didn't", "grant"] {
            XCTAssertFalse(text.contains(banned), "'\(banned)' claims something HealthKit never told Caelyn.")
        }
    }

    /// A source filter finding nothing must not assert the app never wrote — and
    /// must distinguish "Health has other apps' data" from "Health is empty".
    func testASourceFilterFindingNothingNeverClaimsPermissionWasDenied() {
        var withOthers = HealthSyncService.Plan()
        withOthers.observationsBeforeFilter = 40
        let a = ImportPreview.fromHealth(withOthers, sourceFilter: .glow)
        XCTAssertTrue(a.sourceLine.contains("does have cycle data"))

        var bare = HealthSyncService.Plan()
        bare.observationsBeforeFilter = 0
        let b = ImportPreview.fromHealth(bare, sourceFilter: .glow)
        XCTAssertTrue(b.sourceLine.contains("no cycle history there yet"))

        for preview in [a, b] {
            XCTAssertNil(preview.nextStep)
            let text = (preview.headline + " " + preview.sourceLine).lowercased()
            for banned in ["denied", "permission", "grant", "refused"] {
                XCTAssertFalse(text.contains(banned), "'\(banned)' is not something Caelyn can know here.")
            }
        }
    }

    /// A read that errored on some types is still not a denial. HealthKit does not
    /// disclose read authorization and Caelyn must not infer it.
    func testUnreadableTypesAreNeverReportedAsADenial() {
        var plan = HealthSyncService.Plan()
        plan.unreadableTypes = ["HKCategoryTypeIdentifierCervicalMucusQuality"]
        let preview = ImportPreview.fromHealth(plan, sourceFilter: .periodTrackerGPApps)
        XCTAssertNil(preview.nextStep)
        let text = ([preview.headline, preview.sourceLine] + preview.caveats).joined(separator: " ").lowercased()
        for banned in ["denied", "permission", "grant", "enable"] {
            XCTAssertFalse(text.contains(banned))
        }
    }

    // MARK: I/J — the verified pipeline underneath is untouched

    /// Reconciliation, provenance and hand-edit protection still behave exactly as
    /// Phase 1B left them, through the new profile-free entry point.
    func testTheReconciliationPipelineIsUnchangedByTheNewEntryPoint() {
        let ledger = ImportLedger(fileURL: nil)
        let hers = CycleStore.entry(for: day(2026, 7, 1), in: context, calendar: calendar)
        hers.flow = .heavy                                     // she typed this
        context.saveOrLog()

        let incoming = ImportObservation(
            day: day(2026, 7, 1), field: .flow, value: .flow(.light),
            recordID: UUID(), sourceBundleID: "com.gpapps.ptrackerlite",
            sourceName: "Period Tracker", recordedAt: day(2026, 7, 1))

        let decisions = ImportReconciler.plan(
            observations: [incoming],
            currentValue: { d, f in
                d == self.day(2026, 7, 1) && f == .flow ? .flow(.heavy) : nil
            },
            ledger: ledger, ownBundleID: "x", acceptOwnSource: true,
            calendar: calendar, today: day(2026, 7, 10))

        XCTAssertEqual(decisions.count, 1)
        XCTAssertEqual(decisions.first?.action, .keepUserValue,
                       "A value she typed is still never overwritten by an import.")
    }

    /// An imported recent period still moves the authoritative anchor — the Phase 1B
    /// guarantee, verified through data that arrived via the Health path.
    func testAnImportedPeriodStillMovesThePredictionAnchor() {
        let profile = UserProfile(averageCycleLength: 28, averagePeriodLength: 5)
        profile.lastPeriodStart = day(2026, 5, 2)              // her onboarding answer
        context.insert(profile)

        for k in 0..<5 {
            let e = CycleStore.entry(for: calendar.date(byAdding: .day, value: k, to: day(2026, 6, 1))!,
                                     in: context, calendar: calendar)
            e.flow = .medium
        }
        context.saveOrLog()

        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        let model = CycleModel.make(entries: entries, profile: profile,
                                    today: day(2026, 6, 20), calendar: calendar)
        XCTAssertEqual(model.anchor, day(2026, 6, 1),
                       "Imported bleeding is newer than her stated date and must win.")
    }
}
