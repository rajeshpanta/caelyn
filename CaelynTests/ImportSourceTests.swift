import XCTest
import SwiftData
@testable import Caelyn

/// Tests for the file-import pipeline: detection, the source adapters, the
/// preview, and undo.
///
/// The merge rules themselves are covered in `HealthSyncTests` and are not
/// repeated here — that is the point of both paths sharing one reconciler. What
/// these tests guard is everything *around* it: that a file is identified for the
/// right reasons, that a parser refuses rather than guesses, that the preview
/// promises exactly what the commit delivers, and that walking away changes
/// nothing.
@MainActor
final class ImportSourceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var ledger: ImportLedger!
    private let calendar = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self, configurations: config)
        context = container.mainContext
        ledger = ImportLedger(fileURL: nil)
    }

    override func tearDownWithError() throws {
        container = nil; context = nil; ledger = nil
    }

    // MARK: - Helpers

    /// A fixed "today", late enough that every date used in these tests is in the
    /// past — a future-dated row is rejected by design, so a fixture that drifts
    /// past it would fail for the wrong reason.
    private var today: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!)
    }

    private func payload(_ text: String, name: String = "export.csv") -> ImportPayload {
        ImportPayload(filename: name, data: Data(text.utf8))
    }

    private func preview(_ text: String, name: String = "export.csv") throws -> ImportPreview {
        var p = payload(text, name: name)
        return try ImportPlanner.plan(payload: &p, context: context, ledger: ledger,
                                      calendar: calendar, today: today)
    }

    @discardableResult
    private func importing(_ text: String, name: String = "export.csv") throws -> ImportPreview {
        let plan = try preview(text, name: name)
        ImportPlanner.commit(plan, context: context, ledger: ledger, calendar: calendar)
        return plan
    }

    private func entries() -> [CycleEntry] {
        ((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []).sorted { $0.date < $1.date }
    }

    private func entry(_ dateString: String) -> CycleEntry? {
        entries().first { ImportLedger.dayKey($0.date, calendar: calendar) == dateString }
    }

    private func identify(_ text: String, name: String = "file.csv") throws -> ImportSourceID {
        var p = payload(text, name: name)
        return try ImportPlanner.identify(&p).source
    }

    // MARK: - Caelyn's own export

    func testCaelynExportRoundTripsEveryField() throws {
        let day = calendar.date(byAdding: .day, value: -5, to: today)!
        let original = CycleEntry(date: day, flow: .heavy, pain: 7, painTypes: [.cramps, .backPain],
                                  symptoms: [.headache, .bloating], mood: .irritable,
                                  note: "rough day, with \"quotes\" and, commas")
        original.energyLevel = .drained
        original.basalTemperature = 36.42
        original.cervicalMucus = .eggWhite
        original.sexualActivity = true
        original.ovulationTestResult = .positive
        original.pregnancyTest = false
        original.medication = "ibuprofen 400mg"
        original.loggedCustomSymptoms = ["jaw tension"]
        context.insert(original)
        try context.save()

        let csv = ExportService.generateCSV(entries: [original], includeNotes: true)
        try context.delete(model: CycleEntry.self)
        try context.save()

        try importing(csv)

        let restored = try XCTUnwrap(entries().first)
        XCTAssertEqual(restored.flow, .heavy)
        XCTAssertEqual(restored.pain, 7)
        XCTAssertEqual(Set(restored.painTypes), [.cramps, .backPain])
        XCTAssertEqual(Set(restored.symptoms), [.headache, .bloating])
        XCTAssertEqual(restored.mood, .irritable)
        XCTAssertEqual(restored.energyLevel, .drained)
        XCTAssertEqual(restored.basalTemperature ?? 0, 36.42, accuracy: 0.001)
        XCTAssertEqual(restored.cervicalMucus, .eggWhite)
        XCTAssertEqual(restored.sexualActivity, true)
        XCTAssertEqual(restored.ovulationTestResult, .positive)
        XCTAssertEqual(restored.pregnancyTest, false)
        XCTAssertEqual(restored.medication, "ibuprofen 400mg")
        XCTAssertEqual(restored.loggedCustomSymptoms, ["jaw tension"])
        XCTAssertEqual(restored.note, "rough day, with \"quotes\" and, commas")
    }

    func testUnspecifiedFlowRoundTripsThroughCaelynsOwnExport() throws {
        // A day imported from Apple Health without a recorded heaviness must
        // survive an export and re-import as the same thing — not silently
        // become a level she never chose, and not vanish.
        let day = calendar.date(byAdding: .day, value: -9, to: today)!
        let entry = CycleEntry(date: day, flow: .unspecified)
        context.insert(entry)
        try context.save()

        let csv = ExportService.generateCSV(entries: [entry], includeNotes: false)
        XCTAssertTrue(csv.contains("unspecified"), "the export has to carry the value")
        try context.delete(model: CycleEntry.self)
        try context.save()

        try importing(csv)
        XCTAssertEqual(entries().first?.flow, .unspecified)
    }

    func testUnspecifiedSpellingsAreUnderstoodFromAnotherAppsFile() {
        XCTAssertEqual(ImportValues.flow("unspecified"), .unspecified)
        XCTAssertEqual(ImportValues.flow("Unknown"), .unspecified)
        XCTAssertEqual(ImportValues.flow("not recorded"), .unspecified)
        // And the levels she can actually pick are untouched.
        XCTAssertEqual(ImportValues.flow("heavy"), .heavy)
        XCTAssertEqual(ImportValues.flow("light"), .light)
        XCTAssertNil(ImportValues.flow("fluorescent"))
    }

    func testAnUnspecifiedDayCanBeUndoneLikeAnyOther() throws {
        let day = calendar.date(byAdding: .day, value: -8, to: today)!
        let key = ImportLedger.dayKey(day, calendar: calendar)
        let plan = try importing("date,flow\n\(key),unspecified")
        XCTAssertEqual(entry(key)?.flow, .unspecified)

        let outcome = ImportPlanner.undo(batchID: plan.batchID, context: context,
                                         ledger: ledger, calendar: calendar)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertNil(entry(key), "the day is removed just like any other imported day")
    }

    func testUnspecifiedNeverOverwritesAnIntensitySheChose() throws {
        let day = calendar.date(byAdding: .day, value: -7, to: today)!
        let key = ImportLedger.dayKey(day, calendar: calendar)
        let mine = CycleEntry(date: day, flow: .heavy)
        context.insert(mine)
        try context.save()

        let plan = try importing("date,flow\n\(key),unspecified")

        XCTAssertEqual(entry(key)?.flow, .heavy, "a vaguer value must never replace a specific one she chose")
        XCTAssertEqual(plan.summary.keptUserValue, 1)
    }

    // MARK: - Never inventing an intensity

    func testBooleanPeriodColumnBecomesADayWithNoIntensity() throws {
        try importing("""
        date,period
        2026-01-05,yes
        2026-01-06,true
        2026-01-07,no
        """)
        XCTAssertEqual(entry("2026-01-05")?.flow, .unspecified)
        XCTAssertEqual(entry("2026-01-06")?.flow, .unspecified)
        XCTAssertNil(entry("2026-01-07"), "'no' is not a bleeding day and must create nothing")
    }

    func testExplicitLevelsStillMapToThemselves() throws {
        try importing("""
        date,flow
        2026-01-05,light
        2026-01-06,medium
        2026-01-07,heavy
        2026-01-08,spotting
        """)
        XCTAssertEqual(entry("2026-01-05")?.flow, .light)
        XCTAssertEqual(entry("2026-01-06")?.flow, .medium)
        XCTAssertEqual(entry("2026-01-07")?.flow, .heavy)
        XCTAssertEqual(entry("2026-01-08")?.flow, .spotting)
    }

    func testBooleanPeriodDaysStillReconstructIntoCycles() throws {
        var rows = ["date,period"]
        for cycle in 0..<3 {
            for offset in 0..<4 {
                let day = calendar.date(byAdding: .day, value: cycle * 30 + offset,
                                        to: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!)!
                rows.append("\(ImportLedger.dayKey(day, calendar: calendar)),yes")
            }
        }
        try importing(rows.joined(separator: "\n"))
        let cycles = PredictionEngine.cycles(from: entries(), today: today)
        XCTAssertEqual(cycles.count, 2)
        XCTAssertTrue(cycles.allSatisfy { $0.length == 30 },
                      "a day with no recorded intensity is still a period day")
    }

    func testGenericJSONBooleanPeriodAlsoAvoidsInventingALevel() throws {
        let json = """
        [{"date":"2026-01-05","period":true},{"date":"2026-01-06","period":"heavy"}]
        """
        try importing(json, name: "other.json")
        XCTAssertEqual(entry("2026-01-05")?.flow, .unspecified)
        XCTAssertEqual(entry("2026-01-06")?.flow, .heavy)
    }

    func testClueKeepsAPeriodDayItCannotNameTheIntensityOf() throws {
        let json = clueJSON("""
        {"date":"2026-01-05T00:00:00.000Z","type":"period","value":{"option":"some_new_level"}},
        {"date":"2026-01-06T00:00:00.000Z","type":"period","value":{"option":"heavy"}}
        """)
        let plan = try importing(json, name: "measurements.json")
        XCTAssertEqual(entry("2026-01-05")?.flow, .unspecified,
                       "the bleeding day is kept even when the word for it is unknown")
        XCTAssertEqual(entry("2026-01-06")?.flow, .heavy)
        XCTAssertNotNil(plan.parsed.unmappedFields["period: some_new_level"],
                        "and she is told the amount wasn't understood")
    }

    func testAFileNamingTheSameThingTwiceImportsIdenticallyEveryTime() throws {
        // Two keys for one concept. Which one wins must not depend on how the
        // keys happened to hash, or the same file imports differently run to run.
        let json = """
        [{"date":"2026-01-05","flow":"heavy"},
         {"date":"2026-01-06","period":true},
         {"date":"2026-01-07","flow":"light"}]
        """
        var seen: Set<String> = []
        for _ in 0..<5 {
            let container = try ModelContainer(for: CycleEntry.self, UserProfile.self,
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            var p = payload(json, name: "other.json")
            let plan = try ImportPlanner.plan(payload: &p, context: container.mainContext,
                                              ledger: ImportLedger(fileURL: nil),
                                              calendar: calendar, today: today)
            seen.insert("\(plan.summary.daysAffected)|\(plan.summary.changeCount)|\(plan.parsed.unmappedFields.keys.sorted())")
        }
        XCTAssertEqual(seen.count, 1, "the same file must produce the same plan every time")
    }

    func testADuplicateColumnIsNotReportedAsSomethingCaelynCannotUse() throws {
        // "flow" and "period" both mean the same thing. Caelyn reads one of them;
        // telling her it has "no place for" the other would be plainly untrue.
        let plan = try preview("""
        date,flow,period,horoscope
        2026-01-05,heavy,yes,capricorn
        """)
        XCTAssertNil(plan.parsed.unmappedFields["period"])
        XCTAssertNotNil(plan.parsed.unmappedFields["horoscope"],
                        "a column Caelyn genuinely has no concept for is still reported")
    }

    func testCaelynExportIsRecognisedAsCaelynNotAsASpreadsheet() throws {
        let csv = """
        date,flow,pain,pain_types,symptoms,mood,energy_level,medication,basal_temperature,cervical_mucus,sexual_activity,ovulation_test,pregnancy_test,custom_symptoms,note
        2026-01-05,heavy,6,cramps,bloating,sad,low,,36.40,creamy,no,negative,,,
        """
        XCTAssertEqual(try identify(csv), .caelyn)
    }

    func testOlderCaelynExportWithFewerColumnsStillImports() throws {
        // The columns a first-version export carried, and nothing else.
        let csv = """
        date,flow,pain,pain_types,symptoms,mood,note
        2026-01-05,medium,4,cramps,bloating;fatigue,anxious,short note
        2026-01-06,light,,,,,
        """
        XCTAssertEqual(try identify(csv), .caelyn)
        try importing(csv)

        let first = try XCTUnwrap(entry("2026-01-05"))
        XCTAssertEqual(first.flow, .medium)
        XCTAssertEqual(first.pain, 4)
        XCTAssertEqual(Set(first.symptoms), [.bloating, .fatigue])
        XCTAssertEqual(first.mood, .anxious)
        XCTAssertEqual(first.note, "short note")
        XCTAssertEqual(entry("2026-01-06")?.flow, .light)
    }

    func testNewerColumnsInACaelynExportAreReportedNotDropped() throws {
        let csv = """
        date,flow,pain_types,symptoms,sleep_hours
        2026-01-05,medium,cramps,bloating,7.5
        """
        let plan = try preview(csv)
        XCTAssertEqual(plan.source, .caelyn)
        XCTAssertNotNil(plan.parsed.unmappedFields["sleep_hours"])
    }

    // MARK: - Idempotence

    func testSameFileImportedTwiceChangesNothingTheSecondTime() throws {
        let csv = """
        date,flow,symptoms,note
        2026-01-05,heavy,cramps,day one
        2026-01-06,medium,,day two
        2026-01-07,light,,
        """
        let first = try importing(csv)
        XCTAssertEqual(first.summary.daysAffected, 3)

        let second = try preview(csv)
        XCTAssertFalse(second.hasChanges, "a re-import must find nothing left to do")
        XCTAssertEqual(second.summary.filled, 0)
        XCTAssertGreaterThan(second.summary.duplicates, 0)
        XCTAssertEqual(entries().count, 3, "and must not add a single row")
    }

    func testSameRecordsArrivingInTwoDifferentFilesAreNotDuplicated() throws {
        let january = """
        date,flow
        2026-01-05,heavy
        2026-01-06,medium
        """
        // An overlapping export of the same history, plus one new day.
        let overlapping = """
        date,flow
        2026-01-06,medium
        2026-01-07,light
        """
        try importing(january)
        let second = try importing(overlapping)

        XCTAssertEqual(entries().count, 3)
        XCTAssertEqual(second.summary.filled, 1, "only the genuinely new day is written")
        XCTAssertEqual(second.summary.duplicates, 1)
    }

    // MARK: - Her data wins

    func testFileNeverOverwritesSomethingSheLogged() throws {
        let day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let mine = CycleEntry(date: day, flow: .heavy)
        mine.note = "my own words"
        context.insert(mine)
        try context.save()

        let plan = try importing("date,flow,note\n2026-01-05,light,their words")

        XCTAssertEqual(entry("2026-01-05")?.flow, .heavy)
        XCTAssertEqual(entry("2026-01-05")?.note, "my own words")
        XCTAssertEqual(plan.summary.keptUserValue, 2)
    }

    func testAnImportStillFillsTheEmptyFieldsOfADaySheStarted() throws {
        let day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        context.insert(CycleEntry(date: day, flow: .heavy))
        try context.save()

        try importing("date,flow,temperature,mood\n2026-01-05,light,36.55,sad")

        XCTAssertEqual(entry("2026-01-05")?.flow, .heavy, "hers stands")
        XCTAssertEqual(entry("2026-01-05")?.basalTemperature ?? 0, 36.55, accuracy: 0.001)
        XCTAssertEqual(entry("2026-01-05")?.mood, .sad)
    }

    // MARK: - Preview honesty

    func testPreviewCountsMatchWhatCommitActuallyWrites() throws {
        let csv = """
        date,flow,symptoms,temperature,ovulation test,note
        2026-01-05,heavy,cramps,36.40,negative,one
        2026-01-06,medium,bloating;fatigue,36.45,negative,two
        2026-01-07,light,,36.70,lh surge,
        2026-02-40,medium,,,,
        """
        let plan = try preview(csv)
        let promisedDays = plan.summary.daysAffected
        let promisedValues = plan.summary.changeCount

        let outcome = ImportPlanner.commit(plan, context: context, ledger: ledger, calendar: calendar)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.summary.daysAffected, promisedDays)
        XCTAssertEqual(outcome.summary.changeCount, promisedValues)
        XCTAssertEqual(entries().count, promisedDays, "the day count shown is the day count written")
    }

    func testCancellingAfterPreviewChangesNothingAtAll() throws {
        let csv = "date,flow\n2026-01-05,heavy\n2026-01-06,medium"
        let plan = try preview(csv)
        XCTAssertTrue(plan.hasChanges)

        // She reads it and closes the sheet. No commit call.
        XCTAssertEqual(entries().count, 0, "previewing must not write")
        XCTAssertEqual(ledger.claimCount, 0, "previewing must not claim provenance")
        XCTAssertTrue(ledger.batches.isEmpty)
    }

    func testValueLoggedWhilePreviewIsOnScreenSurvivesTheCommit() throws {
        let csv = "date,flow\n2026-01-05,light"
        let plan = try preview(csv)

        // She logs that day before tapping Import.
        let day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let mine = CycleStore.entry(for: day, in: context, calendar: calendar)
        mine.flow = .heavy
        try context.save()

        let outcome = ImportPlanner.commit(plan, context: context, ledger: ledger, calendar: calendar)

        XCTAssertEqual(entry("2026-01-05")?.flow, .heavy)
        XCTAssertEqual(outcome.summary.keptUserValue, 1)
        XCTAssertEqual(outcome.summary.filled, 0)
    }

    func testPreviewCopyStaysOutOfTechnicalLanguage() throws {
        let plan = try preview("date,flow,symptoms\n2026-01-05,heavy,cramps")
        let text = ([plan.headline, plan.sourceLine, plan.safetyLine] + plan.breakdown + plan.caveats)
            .joined(separator: " ")
            .lowercased()
        for jargon in ["csv", "json", "parser", "schema", "healthkit", "column", "field", "adapter", "uuid"] {
            XCTAssertFalse(text.contains(jargon), "leaked '\(jargon)' into what she reads")
        }
    }

    // MARK: - Undo

    func testUndoRemovesOnlyWhatThatImportAdded() throws {
        let day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 6))!
        let mine = CycleEntry(date: day, flow: .heavy)
        context.insert(mine)
        try context.save()

        let plan = try importing("date,flow,mood\n2026-01-05,light,sad\n2026-01-06,medium,anxious")
        XCTAssertEqual(entry("2026-01-05")?.flow, .light)
        XCTAssertEqual(entry("2026-01-06")?.mood, .anxious)

        let outcome = ImportPlanner.undo(batchID: plan.batchID, context: context,
                                         ledger: ledger, calendar: calendar)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertNil(entry("2026-01-05"), "a day the import created is removed entirely")
        XCTAssertEqual(entry("2026-01-06")?.flow, .heavy, "her own value is untouched")
        XCTAssertNil(entry("2026-01-06")?.mood, "the imported value on her day is removed")
    }

    func testUndoLeavesAnythingSheEditedAfterTheImport() throws {
        let plan = try importing("date,flow\n2026-01-05,light")
        entry("2026-01-05")?.flow = .heavy      // she corrects it
        try context.save()

        ImportPlanner.undo(batchID: plan.batchID, context: context, ledger: ledger, calendar: calendar)

        XCTAssertEqual(entry("2026-01-05")?.flow, .heavy, "her correction is hers, not the import's")
    }

    func testUndoingOneImportLeavesAnotherAlone() throws {
        let first = try importing("date,flow\n2026-01-05,light")
        let second = try importing("date,mood\n2026-01-06,sad")

        ImportPlanner.undo(batchID: first.batchID, context: context, ledger: ledger, calendar: calendar)

        XCTAssertNil(entry("2026-01-05"))
        XCTAssertEqual(entry("2026-01-06")?.mood, .sad)
        XCTAssertEqual(ledger.batches.count, 1)
        XCTAssertEqual(ledger.batches.first?.id, second.batchID)
    }

    func testCommittedImportIsRecordedAsAnUndoableBatch() throws {
        let plan = try importing("date,flow\n2026-01-05,light\n2026-01-06,medium")
        let batch = try XCTUnwrap(ledger.batches.first)
        XCTAssertEqual(batch.id, plan.batchID)
        XCTAssertEqual(batch.sourceName, "Spreadsheet")
        XCTAssertEqual(batch.daysAffected, 2)
    }

    // MARK: - Malformed and hostile input

    func testEmptyFileIsRefusedClearly() {
        var p = ImportPayload(filename: "empty.csv", data: Data())
        XCTAssertThrowsError(try ImportPlanner.identify(&p)) { error in
            XCTAssertEqual(error as? ImportSourceError, .empty)
        }
    }

    func testFileWithNoDatesIsRefusedRatherThanPartlyImported() {
        XCTAssertThrowsError(try preview("name,value\nalice,3\nbob,4"))
        XCTAssertEqual(entries().count, 0)
    }

    func testMalformedJSONFallsThroughRatherThanCrashing() {
        XCTAssertThrowsError(try preview("{ \"operationalData\": { \"cycles\": [", name: "broken.json"))
        XCTAssertEqual(entries().count, 0)
    }

    func testBinaryFileIsUnsupportedNotMisread() {
        var p = ImportPayload(filename: "photo.png", data: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01]))
        XCTAssertThrowsError(try ImportPlanner.identify(&p)) { error in
            XCTAssertEqual(error as? ImportSourceError, .unsupported)
        }
    }

    func testOneBadRowDoesNotCostTheRest() throws {
        let csv = """
        date,flow
        2026-01-05,heavy
        not-a-date,medium
        2026-01-07,light
        2026-01-08,fluorescent
        2026-01-09,medium
        """
        let plan = try importing(csv)
        // Three of the five rows carry a day Caelyn can place: the unreadable date
        // and the unrecognised flow word each cost only their own row.
        XCTAssertEqual(entries().count, 3, "readable days survive their neighbours")
        XCTAssertEqual(entry("2026-01-05")?.flow, .heavy)
        XCTAssertEqual(entry("2026-01-07")?.flow, .light)
        XCTAssertEqual(entry("2026-01-09")?.flow, .medium)
        XCTAssertGreaterThan(plan.parsed.rowsSkipped, 0)
        XCTAssertNil(entry("2026-01-08"), "an unrecognised flow word is skipped, not guessed")
    }

    func testImpossibleDatesAreRejected() throws {
        let csv = """
        date,flow
        2026-01-05,heavy
        2026-02-30,medium
        """
        try importing(csv)
        XCTAssertEqual(entries().count, 1)
    }

    func testFutureDatedRowsAreRejected() throws {
        let future = calendar.date(byAdding: .year, value: 1, to: today)!
        let csv = "date,flow\n\(ImportLedger.dayKey(future, calendar: calendar)),heavy"
        let plan = try preview(csv)
        XCTAssertFalse(plan.hasChanges)
        XCTAssertGreaterThan(plan.summary.rejected, 0)
    }

    func testDuplicateHeadersKeepTheLeftmostColumn() throws {
        let csv = """
        date,flow,flow
        2026-01-05,heavy,light
        """
        try importing(csv)
        XCTAssertEqual(entry("2026-01-05")?.flow, .heavy)
    }

    func testReorderedColumnsAreReadByNameNotPosition() throws {
        let csv = """
        note,symptoms,flow,date
        feeling rough,cramps,heavy,2026-01-05
        """
        try importing(csv)
        let day = try XCTUnwrap(entry("2026-01-05"))
        XCTAssertEqual(day.flow, .heavy)
        XCTAssertEqual(day.symptoms, [.cramps])
        XCTAssertEqual(day.note, "feeling rough")
    }

    func testUnknownColumnsAreReportedAndOtherwiseIgnored() throws {
        let csv = """
        date,flow,step_count,horoscope
        2026-01-05,heavy,8123,capricorn
        """
        let plan = try importing(csv)
        XCTAssertEqual(entry("2026-01-05")?.flow, .heavy)
        XCTAssertNotNil(plan.parsed.unmappedFields["step_count"])
        XCTAssertNotNil(plan.parsed.unmappedFields["horoscope"])
    }

    // MARK: - CSV text handling

    func testQuotedNotesKeepTheirCommasQuotesAndNewlines() throws {
        let csv = "date,flow,note\n2026-01-05,heavy,\"one, two \"\"quoted\"\"\nand a new line\""
        try importing(csv)
        XCTAssertEqual(entry("2026-01-05")?.note, "one, two \"quoted\"\nand a new line")
    }

    func testUnicodeNotesSurviveIntact() throws {
        let note = "cramps 😣 — sehr müde, 生理痛"
        let csv = "date,flow,note\n2026-01-05,heavy,\"\(note)\""
        try importing(csv)
        XCTAssertEqual(entry("2026-01-05")?.note, note)
    }

    func testCarriageReturnLineEndingsAreHandled() throws {
        let csv = "date,flow\r\n2026-01-05,heavy\r\n2026-01-06,light\r\n"
        try importing(csv)
        XCTAssertEqual(entries().count, 2)
    }

    func testByteOrderMarkDoesNotBreakTheHeader() throws {
        let csv = "\u{FEFF}date,flow\n2026-01-05,heavy"
        try importing(csv)
        XCTAssertEqual(entry("2026-01-05")?.flow, .heavy)
    }

    // MARK: - Dates

    func testCommonDateFormatsAreAccepted() throws {
        // The written form carries a comma, so in a real CSV it arrives quoted.
        for (format, sample) in [("slashes", "2026/01/05"), ("dotted", "05.01.2026"), ("written", "\"Jan 5, 2026\"")] {
            let container = try ModelContainer(for: CycleEntry.self, UserProfile.self,
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let scratch = container.mainContext
            var p = payload("date,flow\n\(sample),heavy")
            let plan = try ImportPlanner.plan(payload: &p, context: scratch, ledger: ImportLedger(fileURL: nil),
                                              calendar: calendar, today: today)
            XCTAssertTrue(plan.hasChanges, "\(format) dates should be readable")
        }
    }

    func testAmbiguousDateColumnIsResolvedByTheWholeColumnNotRowByRow() throws {
        // Unambiguously day-first: 13 cannot be a month.
        let csv = """
        date,flow
        03/04/2026,heavy
        13/04/2026,light
        """
        try importing(csv)
        let days = entries().map { ImportLedger.dayKey($0.date, calendar: calendar) }
        XCTAssertEqual(days, ["2026-04-03", "2026-04-13"])
    }

    func testAColumnWithNoSingleConsistentFormatIsRefused() {
        // No one format parses every value, so Caelyn declines rather than
        // reading half the file as March and half as April.
        XCTAssertThrowsError(try preview("date,flow\n03/04/2026,heavy\nJan 5 2026,light\n"))
    }

    func testTimestampedDatesLandOnTheirOwnLocalDay() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var p = payload("date,flow\n2026-01-05T23:45:00+09:00,heavy")
        let plan = try ImportPlanner.plan(payload: &p, context: context, ledger: ledger,
                                          calendar: tokyo, today: today)
        ImportPlanner.commit(plan, context: context, ledger: ledger, calendar: tokyo)
        XCTAssertEqual(entries().count, 1)
        XCTAssertEqual(ImportLedger.dayKey(try XCTUnwrap(entries().first).date, calendar: tokyo), "2026-01-05")
    }

    func testImportAcrossADaylightSavingBoundaryKeepsOneRowPerDay() throws {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        // US spring-forward is 2026-03-08.
        var p = payload("date,flow\n2026-03-07,heavy\n2026-03-08,medium\n2026-03-09,light")
        let plan = try ImportPlanner.plan(payload: &p, context: context, ledger: ledger,
                                          calendar: la, today: la.startOfDay(for: today))
        ImportPlanner.commit(plan, context: context, ledger: ledger, calendar: la)

        XCTAssertEqual(entries().count, 3, "the short day is still exactly one day")
        XCTAssertEqual(entries().map { ImportLedger.dayKey($0.date, calendar: la) },
                       ["2026-03-07", "2026-03-08", "2026-03-09"])
    }

    // MARK: - Value mapping

    func testFlowSpellingsAcrossApps() {
        XCTAssertEqual(ImportValues.flow("Spotting"), .spotting)
        XCTAssertEqual(ImportValues.flow("very light"), .spotting)
        XCTAssertEqual(ImportValues.flow("LIGHT"), .light)
        XCTAssertEqual(ImportValues.flow("Moderate"), .medium)
        XCTAssertEqual(ImportValues.flow("2"), .medium)
        XCTAssertEqual(ImportValues.flow("heavy"), .heavy)
        XCTAssertEqual(ImportValues.flow("very_heavy"), .heavy)
        XCTAssertNil(ImportValues.flow("fluorescent"))
        XCTAssertTrue(ImportValues.isExplicitlyNoFlow("none"))
        // A column that only says whether she bled proves the day, not a level.
        for boolean in ["yes", "true", "y", "period"] {
            XCTAssertEqual(ImportValues.flow(boolean), .unspecified,
                           "'\(boolean)' says a period happened, not how heavy it was")
        }
    }

    func testSpottingBecomesASymptomAndNeverAPeriodDay() throws {
        // Three real cycles, with a spotting column marked mid-cycle.
        var rows = ["date,flow,spotting"]
        for cycle in 0..<3 {
            for offset in 0..<4 {
                let day = calendar.date(byAdding: .day, value: cycle * 28 + offset,
                                        to: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!)!
                rows.append("\(ImportLedger.dayKey(day, calendar: calendar)),medium,no")
            }
            let spot = calendar.date(byAdding: .day, value: cycle * 28 + 14,
                                     to: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!)!
            rows.append("\(ImportLedger.dayKey(spot, calendar: calendar)),,yes")
        }
        try importing(rows.joined(separator: "\n"))

        let cycles = PredictionEngine.cycles(from: entries(), today: today)
        XCTAssertEqual(cycles.count, 2, "mid-cycle spotting must not split a cycle")
        XCTAssertTrue(cycles.allSatisfy { $0.length == 28 })
        XCTAssertTrue(entries().contains { $0.symptoms.contains(.irregularBleed) })
    }

    func testTemperatureUnitIsInferredFromTheValueItself() {
        XCTAssertEqual(try XCTUnwrap(ImportValues.temperatureCelsius("36.55")), 36.55, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(ImportValues.temperatureCelsius("97.8")), 36.556, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(ImportValues.temperatureCelsius("97.8 F")), 36.556, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(ImportValues.temperatureCelsius("36,55")), 36.55, accuracy: 0.001)
        XCTAssertNil(ImportValues.temperatureCelsius("512"), "outside any human range")
        XCTAssertNil(ImportValues.temperatureCelsius("2026"), "a year in the temperature column")
    }

    func testFahrenheitColumnImportsAsCelsius() throws {
        try importing("date,temperature\n2026-01-05,97.7\n2026-01-06,98.1")
        XCTAssertEqual(entry("2026-01-05")?.basalTemperature ?? 0, 36.5, accuracy: 0.05)
        XCTAssertEqual(entry("2026-01-06")?.basalTemperature ?? 0, 36.72, accuracy: 0.05)
    }

    func testOvulationTestSpellings() {
        XCTAssertEqual(ImportValues.ovulationTest("negative"), .negative)
        XCTAssertEqual(ImportValues.ovulationTest("LH surge"), .lhSurge)
        XCTAssertEqual(ImportValues.ovulationTest("peak"), .lhSurge)
        XCTAssertEqual(ImportValues.ovulationTest("estrogen surge"), .rising)
        XCTAssertEqual(ImportValues.ovulationTest("Positive"), .positive)
        XCTAssertNil(ImportValues.ovulationTest("maybe"))
    }

    func testSymptomAndMucusSpellings() {
        XCTAssertEqual(ImportValues.symptom("Period cramps"), .cramps)
        XCTAssertEqual(ImportValues.symptom("lower_back"), .backPain)
        XCTAssertEqual(ImportValues.symptom("migraine"), .headache)
        XCTAssertEqual(ImportValues.symptom("breast tenderness"), .tenderBreasts)
        XCTAssertNil(ImportValues.symptom("aura reading"))
        XCTAssertEqual(ImportValues.mucus("Egg White"), .eggWhite)
        XCTAssertEqual(ImportValues.mucus("EWCM"), .eggWhite)
        XCTAssertNil(ImportValues.mucus("blue"))
    }

    func testUnrecognisedSymptomIsReportedRatherThanApproximated() throws {
        let plan = try importing("date,symptoms\n2026-01-05,cramps;telepathy")
        XCTAssertEqual(entry("2026-01-05")?.symptoms, [.cramps])
        XCTAssertNotNil(plan.parsed.unmappedFields["symptom: telepathy"])
    }

    // MARK: - Clue

    private func clueJSON(_ body: String) -> String { "[\(body)]" }

    func testClueExportIsRecognised() throws {
        let json = clueJSON("""
        {"date":"2026-01-05T00:00:00.000Z","type":"period","value":{"option":"heavy"}},
        {"date":"2026-01-06T00:00:00.000Z","type":"feelings","value":[{"option":"happy"}]}
        """)
        XCTAssertEqual(try identify(json, name: "measurements.json"), .clue)
    }

    func testClueEntriesMapOntoCaelynFields() throws {
        let json = clueJSON("""
        {"date":"2026-01-05T00:00:00.000Z","type":"period","value":{"option":"heavy"}},
        {"date":"2026-01-05T00:00:00.000Z","type":"pain","value":[{"option":"period_cramps"}]},
        {"date":"2026-01-05T00:00:00.000Z","type":"feelings","value":[{"option":"angry"}]},
        {"date":"2026-01-05T00:00:00.000Z","type":"energy","value":{"option":"exhausted"}},
        {"date":"2026-01-06T00:00:00.000Z","type":"discharge","value":{"option":"egg_white"}},
        {"date":"2026-01-06T00:00:00.000Z","type":"bbt","value":{"temperature":36.62}},
        {"date":"2026-01-06T00:00:00.000Z","type":"sex_life","value":[{"option":"protected_sex"}]},
        {"date":"2026-01-07T00:00:00.000Z","type":"spotting","value":{"option":"red"}}
        """)
        try importing(json, name: "measurements.json")

        let fifth = try XCTUnwrap(entry("2026-01-05"))
        XCTAssertEqual(fifth.flow, .heavy)
        XCTAssertEqual(fifth.symptoms, [.cramps])
        XCTAssertEqual(fifth.painTypes, [.cramps])
        XCTAssertEqual(fifth.mood, .irritable)
        XCTAssertEqual(fifth.energyLevel, .drained)

        let sixth = try XCTUnwrap(entry("2026-01-06"))
        XCTAssertEqual(sixth.cervicalMucus, .eggWhite)
        XCTAssertEqual(sixth.basalTemperature ?? 0, 36.62, accuracy: 0.001)
        XCTAssertEqual(sixth.sexualActivity, true)

        XCTAssertEqual(entry("2026-01-07")?.symptoms, [.irregularBleed],
                       "Clue spotting is a symptom, never a period day")
        XCTAssertNil(entry("2026-01-07")?.flow)
    }

    func testClueCategoriesCaelynHasNoHomeForAreReported() throws {
        let json = clueJSON("""
        {"date":"2026-01-05T00:00:00.000Z","type":"period","value":{"option":"medium"}},
        {"date":"2026-01-05T00:00:00.000Z","type":"hair","value":{"option":"oily"}},
        {"date":"2026-01-05T00:00:00.000Z","type":"craving","value":{"option":"chocolate"}}
        """)
        let plan = try importing(json, name: "measurements.json")
        XCTAssertNotNil(plan.parsed.unmappedFields["hair"])
        XCTAssertNotNil(plan.parsed.unmappedFields["craving"])
        XCTAssertEqual(entry("2026-01-05")?.flow, .medium)
    }

    func testClueOptionAddedInFutureIsIgnoredNotMisassigned() throws {
        let json = clueJSON("""
        {"date":"2026-01-05T00:00:00.000Z","type":"discharge","value":{"option":"brand_new_option"}}
        """)
        let plan = try importing(json, name: "measurements.json")
        XCTAssertNil(entry("2026-01-05")?.cervicalMucus)
        XCTAssertNotNil(plan.parsed.unmappedFields["discharge: brand_new_option"])
    }

    func testClueImportReconstructsRealCycles() throws {
        var elements: [String] = []
        for cycle in 0..<4 {
            for offset in 0..<5 {
                let day = calendar.date(byAdding: .day, value: cycle * 29 + offset,
                                        to: calendar.date(from: DateComponents(year: 2025, month: 6, day: 1))!)!
                elements.append("{\"date\":\"\(ImportLedger.dayKey(day, calendar: calendar))T00:00:00.000Z\",\"type\":\"period\",\"value\":{\"option\":\"medium\"}}")
            }
        }
        try importing(clueJSON(elements.joined(separator: ",")), name: "measurements.json")
        let cycles = PredictionEngine.cycles(from: entries(), today: today)
        XCTAssertEqual(cycles.count, 3)
        XCTAssertTrue(cycles.allSatisfy { $0.length == 29 })
    }

    // MARK: - Flo

    func testFloExportIsRecognised() throws {
        let json = """
        {"operationalData":{"cycles":[{"period_start_date":"2026-01-05","period_end_date":"2026-01-09"}]}}
        """
        XCTAssertEqual(try identify(json, name: "flo.json"), .flo)
    }

    func testFloCyclesBecomeBleedingDaysAndSayWhatWasAssumed() throws {
        let json = """
        {"operationalData":{"cycles":[
          {"period_start_date":"2026-01-05","period_end_date":"2026-01-09"},
          {"period_start_date":"2026-02-02","period_end_date":"2026-02-06"}
        ]}}
        """
        let plan = try importing(json, name: "flo.json")
        XCTAssertEqual(entries().count, 10)
        XCTAssertTrue(entries().allSatisfy { $0.flow == .unspecified },
                      "Flo proves the day, not the amount — Caelyn must not name a level")
        XCTAssertTrue(plan.parsed.assumptions.contains { $0.contains("didn't include how heavy") },
                      "the assumption must be stated before she confirms")
        XCTAssertFalse(plan.parsed.assumptions.joined().lowercased().contains("medium"),
                       "the caveat must not mention a level Flo never gave")

        let cycles = PredictionEngine.cycles(from: entries(), today: today)
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles.first?.length, 28)
        XCTAssertEqual(cycles.first?.periodLength, 5)
    }

    func testFloCycleWithNoEndDateBecomesASingleDay() throws {
        let json = """
        {"operationalData":{"cycles":[{"period_start_date":"2026-01-05"}]}}
        """
        try importing(json, name: "flo.json")
        XCTAssertEqual(entries().count, 1)
    }

    func testAbsurdlyLongFloPeriodIsRejectedRatherThanWrittenOut() throws {
        let json = """
        {"operationalData":{"cycles":[{"period_start_date":"2026-01-05","period_end_date":"2026-06-05"}]}}
        """
        let plan = try importing(json, name: "flo.json")
        XCTAssertEqual(entries().count, 0)
        XCTAssertGreaterThan(plan.parsed.rowsSkipped, 0)
    }

    func testFloSectionsCaelynCannotVerifyAreReportedNotParsed() throws {
        let json = """
        {"operationalData":{"cycles":[{"period_start_date":"2026-01-05","period_end_date":"2026-01-07"}],
         "symptoms":[{"date":"2026-01-05","name":"cramps"}]},
         "profile":{"name":"someone"}}
        """
        let plan = try importing(json, name: "flo.json")
        XCTAssertNotNil(plan.parsed.unmappedFields["symptoms"])
        XCTAssertNotNil(plan.parsed.unmappedFields["profile"])
        XCTAssertTrue(entries().allSatisfy { $0.symptoms.isEmpty },
                      "an unverified section must not be guessed at")
    }

    // MARK: - Detection safety

    func testAGenericTableIsNeverMistakenForAKnownApp() throws {
        let csv = """
        date,period,notes
        2026-01-05,heavy,whatever
        """
        XCTAssertEqual(try identify(csv), .genericCSV)
    }

    func testAJSONListThatMerelyHasDateAndTypeIsNotClaimedAsClue() throws {
        let json = """
        [{"date":"2026-01-05","type":"weight","value":{"option":"70kg"}},
         {"date":"2026-01-06","type":"weight","value":{"option":"70kg"}},
         {"date":"2026-01-07","type":"weight","value":{"option":"70kg"}}]
        """
        XCTAssertNotEqual(try? identify(json, name: "data.json"), .clue)
    }

    func testASpreadsheetNamedLikeAClueExportIsStillReadAsASpreadsheet() throws {
        let csv = "date,flow\n2026-01-05,heavy"
        XCTAssertEqual(try identify(csv, name: "measurements.json"), .genericCSV,
                       "the filename must never decide how a file is read")
    }

    func testCaelynSignatureNeedsAllThreeColumnsNotJustOne() throws {
        let csv = "date,flow,notes\n2026-01-05,heavy,x"
        XCTAssertEqual(try identify(csv), .genericCSV)
    }

    // MARK: - Scale

    func testLargeHistoricalImportIsHandled() throws {
        var rows = ["date,flow,symptoms,temperature,note"]
        var day = calendar.date(from: DateComponents(year: 2021, month: 1, day: 1))!
        var written = 0
        while day < calendar.date(from: DateComponents(year: 2025, month: 12, day: 31))! {
            let key = ImportLedger.dayKey(day, calendar: calendar)
            rows.append("\(key),medium,cramps;bloating,36.5,day \(written)")
            written += 1
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        let plan = try preview(rows.joined(separator: "\n"))
        XCTAssertEqual(plan.summary.daysAffected, written)
        let outcome = ImportPlanner.commit(plan, context: context, ledger: ledger, calendar: calendar)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(entries().count, written)
    }

    func testPartiallyValidFileImportsWhatItCanAndSaysWhatItCouldNot() throws {
        let csv = """
        date,flow,temperature
        2026-01-05,heavy,36.5
        2026-01-06,heavy,900
        bad-date,light,36.6
        2026-01-08,light,36.7
        """
        let plan = try importing(csv)
        XCTAssertEqual(entry("2026-01-05")?.basalTemperature ?? 0, 36.5, accuracy: 0.001)
        XCTAssertEqual(entry("2026-01-06")?.flow, .heavy)
        XCTAssertNil(entry("2026-01-06")?.basalTemperature, "the impossible temperature alone is dropped")
        XCTAssertEqual(entry("2026-01-08")?.flow, .light)
        XCTAssertFalse(plan.caveats.isEmpty, "she is told what was skipped")
    }
}
