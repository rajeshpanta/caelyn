import XCTest
import SwiftData
@testable import Caelyn

/// Tests for the "Bring your history" flow: the state machine behind the screens.
///
/// These sit on `BringHistoryModel` rather than on SwiftUI views because every
/// rule worth guarding is a rule about *when* something happens — nothing is
/// written before she confirms, a second tap cannot write twice, a failure leaves
/// the store untouched. Those are properties of the flow, not of the pixels.
@MainActor
final class BringHistoryFlowTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var ledger: ImportLedger!
    private var model: BringHistoryModel!
    private let calendar = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self, configurations: config)
        context = container.mainContext
        ledger = ImportLedger(fileURL: nil)
        model = BringHistoryModel(calendar: calendar, ledger: ledger)
    }

    override func tearDownWithError() throws {
        container = nil; context = nil; ledger = nil; model = nil
    }

    // MARK: - Helpers

    private var today: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!)
    }

    private func read(_ text: String, name: String = "export.csv") async {
        await model.read(filename: name, data: Data(text.utf8), context: context, today: today)
    }

    private func entries() -> [CycleEntry] {
        ((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []).sorted { $0.date < $1.date }
    }

    private func entry(_ dayKey: String) -> CycleEntry? {
        entries().first { ImportLedger.dayKey($0.date, calendar: calendar) == dayKey }
    }

    private let sampleCSV = """
    date,flow,symptoms,note
    2026-01-05,heavy,cramps,rough one
    2026-01-06,medium,bloating,
    2026-01-07,light,,
    """

    // MARK: - Reading a file

    func testChoosingAFileProducesAPreviewAndWritesNothing() async {
        await read(sampleCSV)

        XCTAssertEqual(model.phase, .confirming)
        let preview = try? XCTUnwrap(model.preview)
        XCTAssertEqual(preview?.summary.daysAffected, 3)
        XCTAssertEqual(entries().count, 0, "a preview must not write")
        XCTAssertEqual(ledger.claimCount, 0)
        XCTAssertTrue(ledger.batches.isEmpty)
    }

    func testPreviewSurvivesLeavingAndReturningToTheApp() async {
        await read(sampleCSV)
        let promised = model.preview?.summary.changeCount

        // Backgrounding and returning does not touch the model; the sheet is
        // still on screen with the same plan and still nothing written.
        XCTAssertEqual(model.phase, .confirming)
        XCTAssertEqual(model.preview?.summary.changeCount, promised)
        XCTAssertEqual(entries().count, 0)

        model.confirm(context: context)
        XCTAssertEqual(entries().count, 3, "and it still commits exactly what it promised")
    }

    // MARK: - Cancelling

    func testCancellingChangesNothingAtAll() async {
        await read(sampleCSV)
        model.cancel()

        XCTAssertEqual(model.phase, .choosingSource)
        XCTAssertNil(model.preview)
        XCTAssertEqual(entries().count, 0)
        XCTAssertEqual(ledger.claimCount, 0)
        XCTAssertTrue(ledger.batches.isEmpty)
    }

    func testConfirmDoesNothingAfterCancelling() async {
        await read(sampleCSV)
        model.cancel()
        model.confirm(context: context)

        XCTAssertEqual(model.phase, .choosingSource)
        XCTAssertEqual(entries().count, 0)
    }

    // MARK: - Confirming

    func testConfirmingImportsExactlyWhatThePreviewPromised() async {
        await read(sampleCSV)
        let promisedDays = model.preview?.summary.daysAffected
        let promisedValues = model.preview?.summary.changeCount

        model.confirm(context: context)

        guard case .done(let outcome) = model.phase else { return XCTFail("expected a finished import") }
        XCTAssertEqual(outcome.summary.daysAffected, promisedDays)
        XCTAssertEqual(outcome.summary.changeCount, promisedValues)
        XCTAssertEqual(entries().count, 3)
        XCTAssertEqual(entry("2026-01-05")?.flow, .heavy)
        XCTAssertEqual(entry("2026-01-05")?.note, "rough one")
    }

    func testConfirmingTwiceCannotImportTwice() async {
        await read(sampleCSV)
        model.confirm(context: context)
        let batchesAfterFirst = ledger.batches.count

        // A second tap while the first is finishing, and a third afterwards.
        model.confirm(context: context)
        model.confirm(context: context)

        XCTAssertEqual(entries().count, 3, "a double tap must not double the history")
        XCTAssertEqual(ledger.batches.count, batchesAfterFirst)
        XCTAssertEqual(batchesAfterFirst, 1)
    }

    func testFinishedImportIsRecordedAsAnUndoableBatch() async {
        await read(sampleCSV)
        model.confirm(context: context)

        guard case .done(let outcome) = model.phase else { return XCTFail("expected a finished import") }
        let batch = try? XCTUnwrap(ledger.batches.first)
        XCTAssertEqual(batch?.id, outcome.batchID)
        XCTAssertEqual(batch?.daysAffected, 3)
    }

    // MARK: - Undo

    func testUndoRemovesTheImportAndSaysSo() async {
        await read(sampleCSV)
        model.confirm(context: context)

        XCTAssertTrue(model.undoLastImport(context: context))

        XCTAssertEqual(entries().count, 0)
        XCTAssertTrue(ledger.batches.isEmpty)
        guard case .done(let outcome) = model.phase else { return XCTFail("expected the summary to stay on screen") }
        XCTAssertTrue(outcome.undone, "the screen must show that it was undone")
    }

    func testUndoingTwiceIsRefused() async {
        await read(sampleCSV)
        model.confirm(context: context)
        XCTAssertTrue(model.undoLastImport(context: context))
        XCTAssertFalse(model.undoLastImport(context: context))
    }

    func testUndoKeepsAnythingSheEditedAfterTheImport() async {
        await read(sampleCSV)
        model.confirm(context: context)

        entry("2026-01-06")?.flow = .heavy          // she corrects it
        entry("2026-01-07")?.note = "my own note"   // and adds something of her own
        try? context.save()

        XCTAssertTrue(model.undoLastImport(context: context))

        XCTAssertNil(entry("2026-01-05"), "an untouched imported day is removed")
        XCTAssertEqual(entry("2026-01-06")?.flow, .heavy, "her correction survives")
        XCTAssertEqual(entry("2026-01-07")?.note, "my own note", "so does what she added")
        XCTAssertNil(entry("2026-01-07")?.flow, "but the imported value on that day is gone")
    }

    func testUndoBeforeAnyImportDoesNothing() {
        XCTAssertFalse(model.undoLastImport(context: context))
        XCTAssertEqual(entries().count, 0)
    }

    // MARK: - Failure paths

    func testUnsupportedFileFailsWithSomethingActionable() async {
        await model.read(filename: "photo.png",
                         data: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
                         context: context, today: today)

        guard case .failed(let message) = model.phase else { return XCTFail("expected a failure") }
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.lowercased().contains("caelyn"), "the message should say who couldn't do what")
        XCTAssertEqual(entries().count, 0)
    }

    func testMalformedJSONFailsCleanly() async {
        await model.read(filename: "broken.json",
                         data: Data("{ \"operationalData\": { \"cycles\": [".utf8),
                         context: context, today: today)
        guard case .failed = model.phase else { return XCTFail("expected a failure") }
        XCTAssertEqual(entries().count, 0)
    }

    func testEmptyFileFailsCleanly() async {
        await model.read(filename: "empty.csv", data: Data(), context: context, today: today)
        guard case .failed = model.phase else { return XCTFail("expected a failure") }
    }

    func testUnreadableFileURLIsReportedNotCrashed() async {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "definitely-not-here-\(UUID().uuidString).csv")
        await model.readFile(at: missing, context: context, today: today)

        guard case .failed(let message) = model.phase else { return XCTFail("expected a failure") }
        XCTAssertTrue(message.contains("couldn't open"), "a sandbox or missing-file failure should say so")
    }

    func testARealFileOnDiskIsReadThroughTheURLPath() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "history-\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(sampleCSV.utf8).write(to: url)

        await model.readFile(at: url, context: context, today: today)

        XCTAssertEqual(model.phase, .confirming)
        XCTAssertEqual(model.preview?.summary.daysAffected, 3)
    }

    func testDismissingAnErrorReturnsToTheSourcePicker() async {
        await model.read(filename: "empty.csv", data: Data(), context: context, today: today)
        model.dismissError()
        XCTAssertEqual(model.phase, .choosingSource)
    }

    // MARK: - Nothing to do

    func testAFileAlreadyFullyImportedOffersNoSecondImport() async {
        await read(sampleCSV)
        model.confirm(context: context)

        let second = BringHistoryModel(calendar: calendar, ledger: ledger)
        await second.read(filename: "export.csv", data: Data(sampleCSV.utf8), context: context, today: today)

        XCTAssertEqual(second.phase, .confirming)
        XCTAssertEqual(second.preview?.hasChanges, false)
        XCTAssertEqual(entries().count, 3)
    }

    // MARK: - Per-source previews

    func testCluePreviewNamesClueAndDescribesWhatItFound() async {
        let json = """
        [{"date":"2026-01-05T00:00:00.000Z","type":"period","value":{"option":"heavy"}},
         {"date":"2026-01-05T00:00:00.000Z","type":"pain","value":[{"option":"period_cramps"}]},
         {"date":"2026-01-06T00:00:00.000Z","type":"bbt","value":{"temperature":36.62}}]
        """
        await model.read(filename: "measurements.json", data: Data(json.utf8), context: context, today: today)

        let preview = try? XCTUnwrap(model.preview)
        XCTAssertEqual(preview?.source, .clue)
        XCTAssertEqual(preview?.recognisedTheApp, true)
        XCTAssertTrue(preview?.sourceLine.contains("Clue") == true)
        XCTAssertTrue(preview?.breakdown.contains(where: { $0.contains("period day") }) == true)
    }

    func testFloPreviewDisclosesTheMissingIntensityBeforeSheConfirms() async {
        let json = """
        {"operationalData":{"cycles":[{"period_start_date":"2026-01-05","period_end_date":"2026-01-09"}]}}
        """
        await model.read(filename: "flo.json", data: Data(json.utf8), context: context, today: today)

        let preview = try? XCTUnwrap(model.preview)
        XCTAssertEqual(preview?.source, .flo)
        XCTAssertTrue(
            preview?.caveats.contains(where: { $0.contains("didn't include how heavy") }) == true,
            "the assumption Flo forces must be on the confirmation screen, not discovered later"
        )
        XCTAssertFalse(preview?.caveats.joined().lowercased().contains("medium") == true,
                       "and it must not name a level Flo never recorded")
        XCTAssertEqual(entries().count, 0, "and still nothing is written")
    }

    func testGenericPreviewSaysItDidNotRecogniseTheApp() async {
        await read("date,period,notes\n2026-01-05,heavy,fine")
        let preview = try? XCTUnwrap(model.preview)
        XCTAssertEqual(preview?.recognisedTheApp, false)
        XCTAssertTrue(preview?.sourceLine.contains("didn't recognise") == true)
    }

    func testPartialParseWarningsReachTheConfirmationScreen() async {
        await read("""
        date,flow,temperature,horoscope
        2026-01-05,heavy,36.5,capricorn
        2026-01-06,heavy,900,leo
        bad-date,light,36.6,virgo
        """)
        let preview = try? XCTUnwrap(model.preview)
        XCTAssertFalse(preview?.caveats.isEmpty == true, "she is told what was skipped and ignored")
    }

    // MARK: - Apple Health, same screen

    func testAppleHealthPreviewUsesTheSameConfirmationModel() {
        // Built from a plan rather than a live HKHealthStore: what is being checked
        // is that the Health route reaches the same screen with the same promises.
        var summary = ImportReconciler.Summary()
        summary.filled = 42
        summary.daysAffected = 30
        summary.byField = ["flow": 30, "symptom": 12]

        var plan = HealthSyncService.Plan()
        plan.summary = summary

        let preview = ImportPreview.fromHealth(plan)
        XCTAssertEqual(preview.source, .appleHealth)
        XCTAssertTrue(preview.isAppleHealth)
        XCTAssertTrue(preview.hasChanges)
        XCTAssertTrue(preview.sourceLine.contains("already stored on your iPhone"))
        XCTAssertTrue(preview.breakdown.contains("30 period days"))
        XCTAssertFalse(preview.safetyLine.isEmpty)
    }

    func testAppleHealthPreviewMentionsAnythingItCouldNotRead() {
        var plan = HealthSyncService.Plan()
        plan.summary.filled = 1
        plan.summary.daysAffected = 1
        plan.unreadableTypes = ["HKCategoryTypeIdentifierCervicalMucusQuality"]

        let preview = ImportPreview.fromHealth(plan)
        XCTAssertFalse(preview.caveats.isEmpty)
        // And it must not leak the raw type name at her.
        XCTAssertFalse(preview.caveats.joined().contains("HKCategory"))
    }

    // MARK: - Honest summaries

    func testSpanIsDescribedFromTheDataAndNeverExaggerated() async {
        var rows = ["date,flow"]
        var day = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        while day < end {
            rows.append("\(ImportLedger.dayKey(day, calendar: calendar)),medium")
            day = calendar.date(byAdding: .day, value: 28, to: day)!
        }
        await read(rows.joined(separator: "\n"))

        XCTAssertEqual(model.preview?.spanDescription(calendar: calendar), "2 years of history")
    }

    func testAShortImportMakesNoDurationClaim() async {
        await read(sampleCSV)
        XCTAssertNil(model.preview?.spanDescription(calendar: calendar),
                     "three days is not 'a year of history'")
    }

    func testMonthsAreDescribedAsMonths() async {
        var rows = ["date,flow"]
        for month in 1...7 {
            let day = calendar.date(from: DateComponents(year: 2026, month: month, day: 3))!
            rows.append("\(ImportLedger.dayKey(day, calendar: calendar)),medium")
        }
        await read(rows.joined(separator: "\n"))
        // Jan 3rd to Jul 3rd is 181 days. Caelyn rounds down, so it says five
        // months rather than claiming a sixth it doesn't have.
        XCTAssertEqual(model.preview?.spanDescription(calendar: calendar), "5 months of history")
    }

    // MARK: - Large imports

    func testAVeryLargeImportStillPreviewsBeforeWriting() async {
        var rows = ["date,flow,symptoms,temperature,note"]
        var day = calendar.date(from: DateComponents(year: 2021, month: 1, day: 1))!
        var written = 0
        while written < 1500 {
            rows.append("\(ImportLedger.dayKey(day, calendar: calendar)),medium,cramps;bloating,36.5,day \(written)")
            day = calendar.date(byAdding: .day, value: 1, to: day)!
            written += 1
        }
        await read(rows.joined(separator: "\n"))

        XCTAssertEqual(model.phase, .confirming)
        XCTAssertEqual(model.preview?.summary.daysAffected, written)
        XCTAssertEqual(entries().count, 0, "still nothing written until she says so")

        model.confirm(context: context)
        XCTAssertEqual(entries().count, written)
    }

    // MARK: - What the picker offers

    func testPickerOnlyOffersSourcesCaelynCanActuallyRead() {
        let offered = ImportSourceGuide.pickable.map(\.source)
        XCTAssertEqual(Set(offered), Set([.appleHealth, .clue, .flo, .genericCSV, .caelyn]))
        // Natural Cycles and Ovia are unverified and must not be advertised.
        for guide in ImportSourceGuide.pickable {
            let text = ([guide.title, guide.subtitle, guide.note ?? ""] + guide.steps).joined(separator: " ")
            XCTAssertFalse(text.contains("Natural Cycles"))
            XCTAssertFalse(text.contains("Ovia"))
        }
    }

    func testEverySourceGuideExplainsHowToGetTheFile() {
        for guide in ImportSourceGuide.pickable where guide.needsAFile {
            XCTAssertFalse(guide.steps.isEmpty, "\(guide.title) offers a file route with no instructions")
        }
        XCTAssertTrue(ImportSourceGuide.appleHealth.steps.isEmpty, "Apple Health needs no file")
    }

    // MARK: - Period Tracker by GP Apps

    func testPeriodTrackerRoutesThroughAppleHealthAndNeverAsksForAFile() {
        let guide = ImportSourceGuide.periodTracker
        XCTAssertEqual(guide.route, .appleHealthAfterInstructions)
        XCTAssertEqual(guide.source, .appleHealth,
                       "there is no Period Tracker file format, so it must be handled as Apple Health")
        XCTAssertFalse(guide.needsAFile, "sending her to a file browser would be a dead end")
        XCTAssertTrue(guide.hasInstructions, "the sync has to be switched on inside Period Tracker first")
        XCTAssertFalse(guide.steps.isEmpty)
    }

    func testPeriodTrackerKeepsItsOwnNameOnThePicker() {
        // The row says the app she is leaving, even though it routes through Health.
        XCTAssertEqual(ImportSourceGuide.periodTracker.title, "Period Tracker")
        XCTAssertEqual(ImportSourceGuide.appleHealth.title, "Apple Health")
        let titles = ImportSourceGuide.pickable.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "two rows must not share a name")
    }

    func testPeriodTrackerIsHonestAboutWhatCannotComeAcross() {
        let note = ImportSourceGuide.periodTracker.note ?? ""
        for lost in ["notes", "moods", "weight"] {
            XCTAssertTrue(note.lowercased().contains(lost),
                          "the note must say '\(lost)' cannot travel")
        }
    }

    func testEveryPickerRowHasItsOwnIdentity() {
        // Apple Health backs two rows — its own and Period Tracker's. Keying
        // identity on the source would merge them in SwiftUI and give both the
        // same accessibility identifier, so VoiceOver and the UI tests would see
        // one control where there are two.
        let keys = ImportSourceGuide.pickable.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "two rows share an identity: \(keys)")
        XCTAssertNotEqual(ImportSourceGuide.periodTracker.key, ImportSourceGuide.appleHealth.key)
        XCTAssertEqual(ImportSourceGuide.periodTracker.key, "period-tracker")
        XCTAssertEqual(ImportSourceGuide.appleHealth.key, "apple-health")
        for key in keys {
            XCTAssertFalse(key.isEmpty)
            XCTAssertFalse(key.contains(" "), "\(key) would be awkward as an identifier")
        }
    }

    func testPeriodTrackerNamesGPAppsSoSheDoesNotPickTheLookalike() {
        // Two widely-used trackers are both called "Period Tracker" and both have
        // a flower. Caelyn supports GP Apps' — the big pink flower — and the row
        // has to say so, or she follows these steps in the wrong app.
        let guide = ImportSourceGuide.periodTracker
        XCTAssertTrue(guide.subtitle.contains("GP Apps"),
                      "the picker row itself must name the developer")
        let text = (guide.subtitle + " " + (guide.note ?? "")).lowercased()
        XCTAssertTrue(text.contains("flower"), "the icon is how she tells them apart")
        XCTAssertTrue(text.contains("diary"), "and the lookalike should be named as such")
    }

    func testNoPickerRowPromisesAFormatCaelynCannotRead() {
        // A row routing to a file must name a source with a real parser behind it.
        let parseable: Set<ImportSourceID> = [.caelyn, .clue, .flo, .genericCSV, .genericJSON]
        for guide in ImportSourceGuide.pickable where guide.needsAFile {
            XCTAssertTrue(parseable.contains(guide.source),
                          "\(guide.title) sends her to a file browser with no parser behind it")
        }
    }

    func testAddingPeriodTrackerDidNotDisturbTheOtherSources() {
        // Every pre-existing row keeps its route, its name and its action.
        let expected: [(String, ImportSourceGuide.Route, Bool)] = [
            ("Apple Health",  .appleHealth,             false),
            ("Clue",          .fileAfterInstructions,   true),
            ("Flo",           .fileAfterInstructions,   true),
            ("Another app",   .fileAfterInstructions,   true),
            ("Caelyn backup", .fileAfterInstructions,   true)
        ]
        for (title, route, needsFile) in expected {
            guard let guide = ImportSourceGuide.pickable.first(where: { $0.title == title }) else {
                return XCTFail("\(title) disappeared from the picker")
            }
            XCTAssertEqual(guide.route, route, "\(title) changed route")
            XCTAssertEqual(guide.needsAFile, needsFile, "\(title) changed how it is reached")
            XCTAssertFalse(guide.actionLabel.isEmpty)
        }
    }

    func testGuideCopyStaysOutOfTechnicalLanguage() {
        for guide in ImportSourceGuide.all {
            let text = ([guide.title, guide.subtitle, guide.note ?? ""] + guide.steps)
                .joined(separator: " ").lowercased()
            for jargon in ["csv", "schema", "parser", "adapter", "healthkit", "uti", "field mapping"] {
                XCTAssertFalse(text.contains(jargon), "\(guide.title) leaked '\(jargon)'")
            }
        }
    }

    // MARK: - Import history

    func testImportDatesReadAsWordsNotTimestamps() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 9))!
        XCTAssertEqual(ImportHistoryView.when(now, now: now, calendar: calendar), "today")
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(ImportHistoryView.when(yesterday, now: now, calendar: calendar), "yesterday")
        let older = calendar.date(byAdding: .day, value: -30, to: now)!
        let text = ImportHistoryView.when(older, now: now, calendar: calendar)
        XCTAssertFalse(text.contains(":"), "no clock times in her import list")
    }
}
