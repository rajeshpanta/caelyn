import XCTest
import SwiftData
@testable import Caelyn

/// The rules `DailyLogForm`'s three typed fields live by.
///
/// **What these protect.** Note, medication and basal temperature are the only
/// controls on that form that keep a local draft instead of binding straight to
/// the entry — a keyboard needs somewhere to type that is not a store write per
/// keystroke. Before 1.4 that draft was filled once on appear and written back
/// unconditionally on focus loss and on disappear, with nothing to distinguish a
/// value Caelyn had put in the field from a value she had typed into it, and
/// nothing to re-fill it when the entry changed underneath.
///
/// Deleting a day therefore did not delete it: the drafts kept the deleted note,
/// medication and temperature, and the next tab switch wrote all three back.
/// Reproduced on an iPhone 15 Pro Max, not only in a simulator. The same stale
/// copy could overwrite a newer note arriving from another device over iCloud, or
/// a value an import had just written to the day she had open.
///
/// The commit functions are `private` members of a View, so the rules are modelled
/// here against the real store. Every model below mirrors the shipping source; if
/// you change `DailyLogForm`'s seeding or commit logic, change these with it.
@MainActor
final class DailyLogDraftTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        context = container.mainContext
    }
    override func tearDownWithError() throws { container = nil; context = nil }

    private var day: Date { cal.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000)) }

    private func rowsForDay() -> [CycleEntry] {
        ((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? [])
            .filter { cal.isDate($0.date, inSameDayAs: day) }
    }
    private func entry() -> CycleEntry? { rowsForDay().first }

    // MARK: - The form, modelled

    /// Mirrors `DailyLogForm`'s drafts and their seeds.
    private struct Form {
        var noteDraft = "",       noteSeed = ""
        var medicationDraft = "", medicationSeed = ""
        var tempDraft = "",       tempSeed = ""
    }

    private static func tempText(_ v: Double?) -> String {
        v.map { String(format: "%.2f", $0) } ?? ""
    }

    private func storedText() -> (note: String, medication: String, temperature: String) {
        (entry()?.note ?? "", entry()?.medication ?? "", Self.tempText(entry()?.basalTemperature))
    }

    /// `DailyLogForm.seedDrafts()`
    private func seed(_ f: inout Form) {
        let s = storedText()
        f.noteDraft = s.note;             f.noteSeed = s.note
        f.medicationDraft = s.medication; f.medicationSeed = s.medication
        f.tempDraft = s.temperature;      f.tempSeed = s.temperature
    }

    /// `DailyLogForm`'s `.onChange(of: storedText)` handler.
    private func storeChanged(_ f: inout Form) {
        guard entry() != nil else { seed(&f); return }
        let s = storedText()
        if f.noteDraft == f.noteSeed, s.note != f.noteSeed {
            f.noteDraft = s.note; f.noteSeed = s.note
        }
        if f.medicationDraft == f.medicationSeed, s.medication != f.medicationSeed {
            f.medicationDraft = s.medication; f.medicationSeed = s.medication
        }
        if f.tempDraft == f.tempSeed, s.temperature != f.tempSeed {
            f.tempDraft = s.temperature; f.tempSeed = s.temperature
        }
    }

    /// `DailyLogForm.withEntry`
    private func withEntry(_ mutate: (CycleEntry) -> Void) {
        let existing = entry()
        let target = existing ?? CycleEntry(date: day)
        if existing == nil { context.insert(target) }
        mutate(target)
        target.updatedAt = .now
        context.saveOrLog()
    }

    /// `DailyLogForm.commitNote()`
    private func commitNote(_ f: inout Form) {
        guard f.noteDraft != f.noteSeed else { return }
        let value = f.noteDraft.isEmpty ? nil : f.noteDraft
        guard value != nil || entry() != nil else { return }
        guard entry()?.note != value else { f.noteSeed = f.noteDraft; return }
        withEntry { $0.note = value }
        f.noteSeed = f.noteDraft
    }

    /// `DailyLogForm.commitMedication()`
    private func commitMedication(_ f: inout Form) {
        guard f.medicationDraft != f.medicationSeed else { return }
        let value = f.medicationDraft.isEmpty ? nil : f.medicationDraft
        guard value != nil || entry() != nil else { return }
        guard entry()?.medication != value else { f.medicationSeed = f.medicationDraft; return }
        withEntry { $0.medication = value }
        f.medicationSeed = f.medicationDraft
    }

    /// `DailyLogForm.commitBasalTemp()`
    private func commitBasalTemp(_ f: inout Form) {
        guard f.tempDraft != f.tempSeed else { return }
        let trimmed = f.tempDraft.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            guard entry()?.basalTemperature != nil else { f.tempSeed = f.tempDraft; return }
            withEntry { $0.basalTemperature = nil }
            f.tempSeed = f.tempDraft
        } else if let value = Double(trimmed), value >= 35.0, value <= 42.0 {
            guard entry()?.basalTemperature != value else { f.tempSeed = f.tempDraft; return }
            withEntry { $0.basalTemperature = value }
            f.tempSeed = f.tempDraft
        } else {
            f.tempDraft = Self.tempText(entry()?.basalTemperature)
            f.tempSeed = f.tempDraft
        }
    }

    /// `.onDisappear` — what a tab switch runs.
    private func leaveTheForm(_ f: inout Form) {
        commitNote(&f); commitMedication(&f); commitBasalTemp(&f)
    }

    private func makeEntry(note: String? = nil, medication: String? = nil, temp: Double? = nil) {
        let e = CycleStore.entry(for: day, in: context)
        e.note = note; e.medication = medication; e.basalTemperature = temp
        context.saveOrLog()
    }

    // MARK: - A delete has to mean a delete

    func testDeletingTheDayLeavesNothingForTheFormToWriteBack() {
        makeEntry(note: "LH surge detected", medication: "Magnesium", temp: 36.55)
        var form = Form()
        seed(&form)                                     // she opens the Log tab

        if let live = entry() { context.delete(live); context.saveOrLog() }
        storeChanged(&form)                             // the form sees the day go
        leaveTheForm(&form)                             // she switches tabs

        XCTAssertTrue(rowsForDay().isEmpty,
            "A day she permanently deleted came back, rebuilt from the form's stale drafts.")
    }

    func testDeletingTheDayAlsoClearsWhatSheIsLookingAt() {
        makeEntry(note: "LH surge detected", medication: "Magnesium", temp: 36.55)
        var form = Form()
        seed(&form)
        if let live = entry() { context.delete(live); context.saveOrLog() }
        storeChanged(&form)

        XCTAssertEqual(form.noteDraft, "", "the note field still shows the deleted text")
        XCTAssertEqual(form.medicationDraft, "", "the medication field still shows the deleted text")
        XCTAssertEqual(form.tempDraft, "", "the temperature field still shows the deleted reading")
    }

    /// Deleting the day is the later and more explicit instruction, so it wins
    /// even over something she had typed and not yet committed.
    func testADeleteBeatsAnUncommittedEdit() {
        makeEntry(note: "original")
        var form = Form()
        seed(&form)
        form.noteDraft = "half-typed thought"           // uncommitted

        if let live = entry() { context.delete(live); context.saveOrLog() }
        storeChanged(&form)
        leaveTheForm(&form)

        XCTAssertTrue(rowsForDay().isEmpty, "the deleted day must not be rebuilt from an uncommitted draft")
        XCTAssertEqual(form.noteDraft, "")
    }

    // MARK: - The form must never overwrite what it did not write

    func testANewerNoteFromAnotherDeviceIsNotOverwritten() {
        makeEntry(note: "old note")
        var form = Form()
        seed(&form)

        entry()?.note = "note written on my iPad"       // arrives over iCloud
        context.saveOrLog()
        storeChanged(&form)
        leaveTheForm(&form)

        XCTAssertEqual(entry()?.note, "note written on my iPad",
            "the form wrote its stale copy back over a newer value from another device")
        XCTAssertEqual(form.noteDraft, "note written on my iPad", "and she should be shown the newer text")
    }

    func testAnImportIntoTheOpenDayIsNotCleared() {
        makeEntry()                                     // entry exists, medication empty
        var form = Form()
        seed(&form)

        entry()?.medication = "Imported: Iron supplement"
        context.saveOrLog()
        storeChanged(&form)
        leaveTheForm(&form)

        XCTAssertEqual(entry()?.medication, "Imported: Iron supplement",
            "an imported value on the open day was cleared by the form's empty draft")
    }

    func testAnExternalTemperatureIsNotOverwritten() {
        makeEntry(temp: 36.20)
        var form = Form()
        seed(&form)

        entry()?.basalTemperature = 36.75
        context.saveOrLog()
        storeChanged(&form)
        leaveTheForm(&form)

        XCTAssertEqual(entry()?.basalTemperature, 36.75)
        XCTAssertEqual(form.tempDraft, "36.75")
    }

    // MARK: - …while everything she does herself still works

    func testTypingOnABlankDayStillSavesAllThreeFields() {
        var form = Form()
        seed(&form)                                     // no entry yet
        form.noteDraft = "cramped all afternoon"
        form.medicationDraft = "Magnesium"
        form.tempDraft = "36.55"
        leaveTheForm(&form)

        XCTAssertEqual(rowsForDay().count, 1, "typing on a blank day must create exactly one row")
        XCTAssertEqual(entry()?.note, "cramped all afternoon")
        XCTAssertEqual(entry()?.medication, "Magnesium")
        XCTAssertEqual(entry()?.basalTemperature, 36.55)
    }

    func testHerEditBeatsAValueThatArrivedWhileSheWasTyping() {
        makeEntry(note: "old note")
        var form = Form()
        seed(&form)
        form.noteDraft = "old note, now edited"         // mid-edit

        entry()?.note = "something from elsewhere"
        context.saveOrLog()
        storeChanged(&form)

        XCTAssertEqual(form.noteDraft, "old note, now edited",
            "an in-progress edit was yanked out from under her")
        leaveTheForm(&form)
        XCTAssertEqual(entry()?.note, "old note, now edited", "and it must win on commit")
    }

    func testClearingANoteStillClearsIt() {
        makeEntry(note: "to be cleared")
        var form = Form()
        seed(&form)
        form.noteDraft = ""                             // select all, delete
        leaveTheForm(&form)

        XCTAssertNil(entry()?.note)
    }

    func testClearingATemperatureStillClearsIt() {
        makeEntry(temp: 36.55)
        var form = Form()
        seed(&form)
        form.tempDraft = ""
        leaveTheForm(&form)

        XCTAssertNil(entry()?.basalTemperature)
    }

    /// stz-011 — simply visiting a blank day must not create a row.
    func testAnUntouchedBlankFormStillCreatesNothing() {
        var form = Form()
        seed(&form)
        leaveTheForm(&form)
        XCTAssertTrue(rowsForDay().isEmpty)
    }

    /// stz-012 — revisiting a day must not rewrite or re-round what is stored.
    func testRevisitingADayNeverRewritesTheStoredTemperature() {
        makeEntry(temp: 36.55)
        let before = entry()?.updatedAt
        var form = Form()
        seed(&form)
        leaveTheForm(&form)

        XCTAssertEqual(entry()?.basalTemperature, 36.55)
        XCTAssertEqual(entry()?.updatedAt, before, "an untouched visit rewrote the entry")
    }

    /// stz-012 — an impossible reading is refused and the field snaps back to the
    /// stored value at full precision.
    func testAnOutOfRangeTemperatureIsRefusedAndTheFieldSnapsBack() {
        makeEntry(temp: 36.55)
        var form = Form()
        seed(&form)
        form.tempDraft = "43.9"
        leaveTheForm(&form)

        XCTAssertEqual(entry()?.basalTemperature, 36.55, "an impossible reading was stored")
        XCTAssertEqual(form.tempDraft, "36.55", "the field should snap back to the stored reading")
    }

    func testCommittingTwiceWritesOnlyOnce() {
        var form = Form()
        seed(&form)
        form.noteDraft = "one thought"
        leaveTheForm(&form)
        let after = entry()?.updatedAt

        leaveTheForm(&form)                             // focus loss, then onDisappear
        XCTAssertEqual(entry()?.updatedAt, after, "the second commit rewrote an unchanged value")
        XCTAssertEqual(rowsForDay().count, 1)
    }
}
