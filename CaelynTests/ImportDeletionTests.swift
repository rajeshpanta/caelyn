import XCTest
@testable import Caelyn

/// A value edited in her old app must arrive as an edit, not as a deletion.
///
/// **What this protects.** Several trackers represent an edit as a delete plus a
/// re-add under a fresh record id, so one sync batch carries both halves: the new
/// reading, and a deletion of the record the old reading came from.
///
/// `plan` decided the deletion against `currentValue`, which reads the store as
/// it stands *before* any of the plan's own writes. So on an edit the old value
/// was still there, the ledger claim still matched, and a `.clear` was appended
/// after the `.update` — and applied after it. Her corrected reading was written
/// and then erased, and a day holding nothing else was deleted outright.
///
/// From her side: she fixed a value in the app she is migrating from, synced, and
/// Caelyn lost the day.
@MainActor
final class ImportDeletionTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let otherApp = "com.example.tracker"
    private let ownBundle = "smallpanta-icould.com.caelynperiodtracker"

    private func day(_ offset: Int) -> Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000 + Double(offset) * 86_400))
    }

    private func observation(day: Date, field: ImportObservation.Field,
                             value: ImportObservation.Value,
                             recordID: UUID = UUID()) -> ImportObservation {
        ImportObservation(
            day: day, field: field, value: value,
            recordID: recordID, sourceBundleID: otherApp, sourceName: "Clue",
            recordedAt: Date(timeIntervalSince1970: 1_780_500_000))
    }

    /// A ledger that already holds a claim for `value` on `day`.
    private func ledgerClaiming(day: Date, field: ImportObservation.Field,
                                value: ImportObservation.Value,
                                recordID: UUID) -> ImportLedger {
        let ledger = ImportLedger(fileURL: nil)
        ledger.record(observation(day: day, field: field, value: value, recordID: recordID),
                      calendar: calendar)
        return ledger
    }

    // MARK: - An edit must survive

    func testAnEditDeliveredAsDeletePlusReAddIsNotErased() {
        let d = day(0)
        let oldRecord = UUID()
        let ledger = ledgerClaiming(day: d, field: .flow, value: .flow(.medium), recordID: oldRecord)

        let decisions = ImportReconciler.plan(
            observations: [observation(day: d, field: .flow, value: .flow(.heavy))],
            deletedRecordIDs: [oldRecord],
            currentValue: { askedDay, askedField in
                // The store still holds the pre-edit value, which is the whole
                // reason the old code mistook the edit for a deletion.
                (askedDay == d && askedField == .flow) ? .flow(.medium) : nil
            },
            ledger: ledger,
            ownBundleID: ownBundle,
            acceptOwnSource: false,
            calendar: calendar,
            today: day(5))

        XCTAssertFalse(decisions.contains { $0.action == .clear },
            "the edit was applied and then cleared by the deletion of the record it replaced — her corrected reading is gone, and so is the day if nothing else was on it")
        XCTAssertTrue(decisions.contains { $0.action == .update || $0.action == .fill },
            "the new value should still be written")
    }

    /// Only the replaced field is spared. A record that carried two fields and
    /// comes back carrying one has genuinely dropped the other.
    func testAFieldTheSourceDidNotResendIsStillCleared() {
        let d = day(0)
        let oldRecord = UUID()
        let ledger = ImportLedger(fileURL: nil)
        ledger.record(observation(day: d, field: .flow, value: .flow(.medium), recordID: oldRecord),
                      calendar: calendar)
        ledger.record(observation(day: d, field: .painScore, value: .painScore(3), recordID: oldRecord),
                      calendar: calendar)

        let decisions = ImportReconciler.plan(
            observations: [observation(day: d, field: .flow, value: .flow(.heavy))],
            deletedRecordIDs: [oldRecord],
            currentValue: { askedDay, askedField in
                guard askedDay == d else { return nil }
                switch askedField {
                case .flow: return .flow(.medium)
                case .painScore: return .painScore(3)
                default:    return nil
                }
            },
            ledger: ledger,
            ownBundleID: ownBundle,
            acceptOwnSource: false,
            calendar: calendar,
            today: day(5))

        let cleared: Set<ImportObservation.Field> = Set(
            decisions.filter { $0.action == .clear }.map(\.field))
        XCTAssertFalse(cleared.contains(.flow),
            "flow was resent, so it was edited rather than deleted")
        XCTAssertTrue(cleared.contains(.painScore),
            "the pain score was not resent, so the source really did remove it")
    }

    // MARK: - A real deletion still deletes

    func testARealDeletionStillClearsTheField() {
        let d = day(0)
        let oldRecord = UUID()
        let ledger = ledgerClaiming(day: d, field: .flow, value: .flow(.medium), recordID: oldRecord)

        let decisions = ImportReconciler.plan(
            observations: [],
            deletedRecordIDs: [oldRecord],
            currentValue: { askedDay, askedField in
                (askedDay == d && askedField == .flow) ? .flow(.medium) : nil
            },
            ledger: ledger,
            ownBundleID: ownBundle,
            acceptOwnSource: false,
            calendar: calendar,
            today: day(5))

        let cleared: Set<ImportObservation.Field> = Set(
            decisions.filter { $0.action == .clear }.map(\.field))
        XCTAssertTrue(cleared.contains(.flow),
            "a deletion with no replacement must still clear the value Caelyn imported")
    }

    /// And a value she has since changed herself is still hers, either way.
    func testHerOwnEditIsNeverClearedByADeletion() {
        let d = day(0)
        let oldRecord = UUID()
        let ledger = ledgerClaiming(day: d, field: .flow, value: .flow(.medium), recordID: oldRecord)

        let decisions = ImportReconciler.plan(
            observations: [],
            deletedRecordIDs: [oldRecord],
            currentValue: { askedDay, askedField in
                // She changed it to light after the import.
                (askedDay == d && askedField == .flow) ? .flow(.light) : nil
            },
            ledger: ledger,
            ownBundleID: ownBundle,
            acceptOwnSource: false,
            calendar: calendar,
            today: day(5))

        XCTAssertFalse(decisions.contains { $0.action == .clear },
            "a deletion at the source reached in and removed a value she had typed herself")
    }

    /// A deletion for a day the batch touches elsewhere must still apply to its
    /// own field — the guard is per day *and* field, not per day.
    func testTheGuardIsPerFieldNotPerDay() {
        let d = day(0)
        let oldRecord = UUID()
        let ledger = ledgerClaiming(day: d, field: .painScore, value: .painScore(2), recordID: oldRecord)

        let decisions = ImportReconciler.plan(
            observations: [observation(day: d, field: .flow, value: .flow(.heavy))],
            deletedRecordIDs: [oldRecord],
            currentValue: { askedDay, askedField in
                guard askedDay == d else { return nil }
                return askedField == .painScore ? .painScore(2) : nil
            },
            ledger: ledger,
            ownBundleID: ownBundle,
            acceptOwnSource: false,
            calendar: calendar,
            today: day(5))

        let cleared: Set<ImportObservation.Field> = Set(
            decisions.filter { $0.action == .clear }.map(\.field))
        XCTAssertTrue(cleared.contains(.painScore),
            "a flow update on the same day suppressed an unrelated pain-score deletion")
    }
}
