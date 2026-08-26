import Foundation
import SwiftData

/// The single merge engine. Every imported value passes through here, whether it
/// came from Apple Health or from a file another app exported. One policy, one
/// place, one set of tests — a second conflict engine is how two import paths end
/// up disagreeing about whose data wins.
///
/// It is split into `plan` and `commit` on purpose. `plan` is pure: it takes the
/// observations, a way to read what Caelyn currently holds, and the provenance
/// ledger, and returns a list of decisions without touching anything. That is
/// what lets Caelyn *show her what will happen before it happens*, and it is what
/// makes the merge rules testable without a database.
///
/// ## The rules, in priority order
///
/// 1. A value she typed is never overwritten. Not by a newer record, not by a
///    "better" source, not ever. Conflicts are reported, not resolved.
/// 2. A value Caelyn imported and still owns may be updated by its own source, or
///    cleared if that source deleted it.
/// 3. The moment a stored value stops matching what was imported, she has edited
///    it — provenance is released and rule 1 takes over permanently.
/// 4. Anything already merged is a no-op, so importing twice changes nothing.
/// 5. Anything that fails validation is rejected with a reason, never silently
///    dropped and never written.
@MainActor
enum ImportReconciler {

    // MARK: - Decisions

    enum Action: Equatable, Sendable {
        /// Field was empty — the imported value fills it.
        case fill
        /// Caelyn still owns this field and its source changed the value.
        case update
        /// She typed something here. Her value stands.
        case keepUserValue
        /// This record has already been merged.
        case duplicate
        /// Source deleted the record and Caelyn still owned the value.
        case clear
        case rejected(Rejection)
    }

    enum Rejection: String, Equatable, Sendable {
        case futureDate
        case implausibleDate
        case temperatureOutOfRange
        case severityOutOfRange
        case painScoreOutOfRange
        case emptyText
        case textTooLong
        /// Superseded by another observation for the same day and field in the
        /// same batch (the more recently recorded one wins).
        case supersededInBatch
    }

    struct Decision: Equatable, Sendable {
        let day: Date
        let field: ImportObservation.Field
        let action: Action
        /// Absent only for `.clear`, which originates from a deletion rather than
        /// from an incoming value.
        let observation: ImportObservation?
    }

    // MARK: - Summary

    /// What a plan would do, in the shape the confirmation screen needs.
    struct Summary: Equatable, Sendable {
        var filled = 0
        var updated = 0
        var keptUserValue = 0
        var duplicates = 0
        var cleared = 0
        var rejected = 0
        /// Distinct days that would gain or change a value — the honest
        /// denominator for "we found N days of history".
        var daysAffected = 0
        /// Counts per field kind, keyed by `Field.ledgerKey`'s prefix, for the
        /// "54 cycles / 214 symptoms / 91 temperatures" breakdown.
        var byField: [String: Int] = [:]

        var changeCount: Int { filled + updated + cleared }
        var isEmpty: Bool { changeCount == 0 }
    }

    static func summarize(_ decisions: [Decision]) -> Summary {
        var summary = Summary()
        var days: Set<Date> = []
        for decision in decisions {
            switch decision.action {
            case .fill:
                summary.filled += 1
                days.insert(decision.day)
                summary.byField[decision.field.summaryKey, default: 0] += 1
            case .update:
                summary.updated += 1
                days.insert(decision.day)
                summary.byField[decision.field.summaryKey, default: 0] += 1
            case .clear:
                summary.cleared += 1
                days.insert(decision.day)
            case .keepUserValue: summary.keptUserValue += 1
            case .duplicate:     summary.duplicates += 1
            case .rejected:      summary.rejected += 1
            }
        }
        summary.daysAffected = days.count
        return summary
    }

    // MARK: - Plan (pure)

    /// Decide what should happen, changing nothing.
    ///
    /// - Parameters:
    ///   - currentValue: what Caelyn holds for a day/field right now.
    ///   - deletedRecordIDs: records the source reports as deleted since the last sync.
    ///   - ownBundleID: Caelyn's own bundle identifier. Observations carrying it are
    ///     dropped unless `acceptOwnSource` is set — this is the sync-loop breaker.
    ///   - acceptOwnSource: true only for a full restore (e.g. after a reinstall,
    ///     when Caelyn's own past writes are the history worth recovering).
    static func plan(
        observations: [ImportObservation],
        deletedRecordIDs: [UUID] = [],
        currentValue: (Date, ImportObservation.Field) -> ImportObservation.Value?,
        ledger: ImportLedger,
        ownBundleID: String,
        acceptOwnSource: Bool,
        calendar: Calendar = .current,
        today: Date = .now
    ) -> [Decision] {
        var decisions: [Decision] = []

        // 1. Drop our own records unless this is an explicit restore. Doing this
        //    first means a loop can't even be described, let alone executed.
        let incoming = acceptOwnSource
            ? observations
            : observations.filter { $0.sourceBundleID != ownBundleID }

        // 2. Collapse the batch to one observation per day+field. Two apps writing
        //    the same field on the same day is normal; the more recently recorded
        //    one wins, and the loser is reported rather than silently discarded.
        var best: [Key: ImportObservation] = [:]
        var superseded: [ImportObservation] = []
        for observation in incoming {
            let day = calendar.startOfDay(for: observation.day)
            let key = Key(day: day, field: observation.field)
            if let existing = best[key] {
                if observation.recordedAt > existing.recordedAt {
                    best[key] = observation
                    superseded.append(existing)
                } else {
                    superseded.append(observation)
                }
            } else {
                best[key] = observation
            }
        }
        for loser in superseded {
            decisions.append(Decision(day: calendar.startOfDay(for: loser.day),
                                      field: loser.field,
                                      action: .rejected(.supersededInBatch),
                                      observation: loser))
        }

        // 3. Decide each surviving observation.
        let todayStart = calendar.startOfDay(for: today)
        let floor = calendar.date(byAdding: .year, value: -50, to: todayStart) ?? .distantPast

        for (key, observation) in best.sorted(by: { $0.key.day < $1.key.day }) {
            let day = key.day

            if let rejection = validate(observation, day: day, todayStart: todayStart, floor: floor) {
                decisions.append(Decision(day: day, field: key.field, action: .rejected(rejection), observation: observation))
                continue
            }

            let stored = currentValue(day, key.field)
            let claim = ledger.claim(day: day, field: key.field, calendar: calendar)

            // Field is empty — nothing to protect, take the value.
            guard let stored else {
                decisions.append(Decision(day: day, field: key.field, action: .fill, observation: observation))
                continue
            }

            // Field is filled. Does Caelyn still own it?
            guard let claim, claim.importedValue == stored.ledgerValue else {
                // Either never imported, or imported and since edited by hand.
                // Both mean it is hers now.
                decisions.append(Decision(day: day, field: key.field, action: .keepUserValue, observation: observation))
                continue
            }

            // Caelyn owns it. Same record and same value → already merged.
            if claim.recordID == observation.recordID, claim.importedValue == observation.value.ledgerValue {
                decisions.append(Decision(day: day, field: key.field, action: .duplicate, observation: observation))
                continue
            }

            // A different record may only take over a field Caelyn owns if it is
            // at least as recent as the one that put the value there. The
            // comparison is between the two *sources'* clocks — `importedAt` is
            // Caelyn's own wall clock and says nothing about which reading is
            // newer. A ledger written before `recordedAt` existed simply lets the
            // newer record win, which is the same outcome as a tie.
            if claim.recordID != observation.recordID,
               let previouslyRecordedAt = claim.recordedAt,
               observation.recordedAt < previouslyRecordedAt {
                decisions.append(Decision(day: day, field: key.field, action: .duplicate, observation: observation))
                continue
            }

            if claim.importedValue == observation.value.ledgerValue {
                decisions.append(Decision(day: day, field: key.field, action: .duplicate, observation: observation))
            } else {
                decisions.append(Decision(day: day, field: key.field, action: .update, observation: observation))
            }
        }

        // 4. Deletions. A record vanishing at its source only clears a field that
        //    Caelyn still owns and that still holds exactly what was imported.
        for recordID in deletedRecordIDs {
            for claim in ledger.claims(forRecord: recordID) {
                guard let field = ImportObservation.Field(ledgerKey: claim.fieldKey),
                      let day = dayFromKey(claim.dayKey, calendar: calendar)
                else { continue }
                guard let stored = currentValue(day, field), stored.ledgerValue == claim.importedValue else {
                    // She has since changed or cleared it — leave it alone.
                    continue
                }
                decisions.append(Decision(day: day, field: field, action: .clear, observation: nil))
            }
        }

        return decisions
    }

    private struct Key: Hashable {
        let day: Date
        let field: ImportObservation.Field
    }

    private static func validate(
        _ observation: ImportObservation,
        day: Date,
        todayStart: Date,
        floor: Date
    ) -> Rejection? {
        if day > todayStart { return .futureDate }
        if day < floor { return .implausibleDate }
        switch observation.value {
        case .temperature(let celsius):
            // Wider than any human reading, narrow enough to catch a Fahrenheit
            // value or a parse slip that landed a year number in the column.
            guard celsius >= 30, celsius <= 45, celsius.isFinite else { return .temperatureOutOfRange }
        case .symptomSeverity(let level):
            guard (1...3).contains(level) else { return .severityOutOfRange }
        case .painScore(let score):
            guard (0...10).contains(score) else { return .painScoreOutOfRange }
        case .text(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .emptyText }
            // A note that dwarfs any real diary entry is a parse slip — most often
            // an entire unquoted file collapsed into one cell.
            guard text.count <= 10_000 else { return .textTooLong }
        default:
            break
        }
        return nil
    }

    private static func dayFromKey(_ dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2]
        return calendar.date(from: comps).map { calendar.startOfDay(for: $0) }
    }

    // MARK: - Commit

    /// Outcome of a commit — including whether it actually landed.
    struct CommitResult {
        var summary: Summary
        var succeeded: Bool
        /// Set when the save failed and everything was rolled back.
        var failure: String?

        static func rolledBack(_ message: String) -> CommitResult {
            CommitResult(summary: Summary(), succeeded: false, failure: message)
        }
    }

    /// Apply an already-reviewed plan. Only `.fill`, `.update` and `.clear` touch
    /// the store; everything else was a report.
    ///
    /// Entries are created through `CycleStore.entry(for:)` so imports obey the
    /// same one-row-per-day invariant as every other write path.
    ///
    /// All or nothing. Every change is staged, then saved once; if that save
    /// fails the context is rolled back and the ledger re-read from disk, so the
    /// store and the record of what came from where can never disagree. Provenance
    /// is written only after the data it describes is safely on disk.
    @discardableResult
    static func commit(
        _ decisions: [Decision],
        into context: ModelContext,
        ledger: ImportLedger,
        batchID: UUID? = nil,
        calendar: Calendar = .current
    ) -> CommitResult {
        var touched = false
        /// Provenance to record, held back until the save succeeds.
        var pendingClaims: [ImportObservation] = []
        var pendingReleases: [(Date, ImportObservation.Field)] = []
        /// Decisions that were valid when planned but no longer are, because she
        /// logged something on that day in the meantime. Counted as values kept.
        var stale = 0

        for decision in decisions {
            switch decision.action {
            case .fill, .update:
                guard let observation = decision.observation else { continue }
                let entry = CycleStore.entry(for: decision.day, in: context, calendar: calendar)

                // Re-check against the live row rather than trusting the plan.
                // A plan she is shown and then confirms leaves a window in which
                // she could log something on one of those very days, and rule 1
                // has to hold across that window too.
                if let live = entry.value(for: decision.field) {
                    let claim = ledger.claim(day: decision.day, field: decision.field, calendar: calendar)
                    guard let claim, claim.importedValue == live.ledgerValue else {
                        // Filled by hand since the plan was made — it is hers.
                        pendingReleases.append((decision.day, decision.field))
                        stale += 1
                        continue
                    }
                }

                entry.apply(observation.value, to: decision.field)
                entry.updatedAt = .now
                pendingClaims.append(observation)
                touched = true

            case .clear:
                let entry = CycleStore.entry(for: decision.day, in: context, calendar: calendar)
                entry.clear(decision.field)
                entry.updatedAt = .now
                pendingReleases.append((decision.day, decision.field))
                // A day emptied by a deletion should not linger as a blank row.
                if !entry.hasContent { context.delete(entry) }
                touched = true

            case .keepUserValue:
                // Her value stands, and the field is hers — drop any stale claim so
                // no future sync mistakes it for Caelyn-owned data.
                pendingReleases.append((decision.day, decision.field))

            case .duplicate, .rejected:
                continue
            }
        }

        if touched {
            do {
                try context.save()
            } catch {
                // Put the store back exactly as it was and forget the provenance
                // that would have described writes which never happened.
                context.rollback()
                ledger.discardUnsavedChanges()
                return .rolledBack(error.localizedDescription)
            }
        }

        for observation in pendingClaims { ledger.record(observation, batchID: batchID, calendar: calendar) }
        for (day, field) in pendingReleases { ledger.release(day: day, field: field, calendar: calendar) }
        ledger.save()

        var summary = summarize(decisions)
        if stale > 0 {
            // Report them the way she would understand them: Caelyn found
            // something and kept what she had written instead.
            summary.keptUserValue += stale
            summary.filled = max(0, summary.filled - stale)
        }
        return CommitResult(summary: summary, succeeded: true, failure: nil)
    }
}

// MARK: - Field access

extension ImportObservation.Field {
    /// Coarse grouping used for the "what we found" breakdown.
    var summaryKey: String {
        switch self {
        case .flow:             return "flow"
        case .basalTemperature: return "temperature"
        case .cervicalMucus:    return "mucus"
        case .ovulationTest:    return "ovulationTest"
        case .pregnancyTest:    return "pregnancyTest"
        case .sexualActivity:   return "sexualActivity"
        case .symptom:          return "symptom"
        case .painType:         return "pain"
        case .painScore:        return "pain"
        case .mood:             return "mood"
        case .energy:           return "energy"
        case .medication:       return "medication"
        case .note:             return "note"
        case .customSymptom:    return "symptom"
        }
    }

    /// Rebuild a field from its ledger key — needed when a deletion gives us
    /// nothing but stored provenance to work from.
    init?(ledgerKey: String) {
        switch ledgerKey {
        case "flow":     self = .flow
        case "bbt":      self = .basalTemperature
        case "mucus":    self = .cervicalMucus
        case "lh":       self = .ovulationTest
        case "pregtest": self = .pregnancyTest
        case "sex":        self = .sexualActivity
        case "painscore":  self = .painScore
        case "mood":       self = .mood
        case "energy":     self = .energy
        case "medication": self = .medication
        case "note":       self = .note
        default:
            if let raw = ledgerKey.dropPrefix("symptom:"), let symptom = Symptom(rawValue: raw) {
                self = .symptom(symptom)
            } else if let raw = ledgerKey.dropPrefix("pain:"), let pain = PainType(rawValue: raw) {
                self = .painType(pain)
            } else if let raw = ledgerKey.dropPrefix("custom:"), !raw.isEmpty {
                self = .customSymptom(raw)
            } else {
                return nil
            }
        }
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}

extension CycleEntry {
    /// Current value of a field, in the merge engine's vocabulary. `nil` means
    /// "nothing logged here", which is the only state an import may fill freely.
    func value(for field: ImportObservation.Field) -> ImportObservation.Value? {
        switch field {
        case .flow:             return flow.map { .flow($0) }
        case .basalTemperature: return basalTemperature.map { .temperature($0) }
        case .cervicalMucus:    return cervicalMucus.map { .mucus($0) }
        case .ovulationTest:    return ovulationTestResult.map { .ovulation($0) }
        case .pregnancyTest:    return pregnancyTest.map { .boolean($0) }
        case .sexualActivity:   return sexualActivity.map { .boolean($0) }
        case .symptom(let symptom):
            guard symptoms.contains(symptom) else { return nil }
            return .symptomSeverity(symptomSeverity[symptom.rawValue] ?? 2)
        case .painType(let pain):
            return painTypes.contains(pain) ? .present : nil
        case .painScore:  return pain.map { .painScore($0) }
        case .mood:       return mood.map { .mood($0) }
        case .energy:     return energyLevel.map { .energy($0) }
        case .medication: return medication.flatMap { $0.isEmpty ? nil : .text($0) }
        case .note:       return note.flatMap { $0.isEmpty ? nil : .text($0) }
        case .customSymptom(let name):
            return loggedCustomSymptoms.contains(name) ? .present : nil
        }
    }

    func apply(_ value: ImportObservation.Value, to field: ImportObservation.Field) {
        switch (field, value) {
        case (.flow, .flow(let f)):                     flow = f
        case (.basalTemperature, .temperature(let t)):  basalTemperature = t
        case (.cervicalMucus, .mucus(let m)):           cervicalMucus = m
        case (.ovulationTest, .ovulation(let o)):       ovulationTestResult = o
        case (.pregnancyTest, .boolean(let b)):         pregnancyTest = b
        case (.sexualActivity, .boolean(let b)):        sexualActivity = b
        case (.symptom(let symptom), .symptomSeverity(let level)):
            if !symptoms.contains(symptom) { symptoms.append(symptom) }
            symptomSeverity[symptom.rawValue] = level
        case (.symptom(let symptom), .present):
            if !symptoms.contains(symptom) { symptoms.append(symptom) }
        case (.painType(let pain), _):
            if !painTypes.contains(pain) { painTypes.append(pain) }
        case (.painScore, .painScore(let score)):   pain = score
        case (.mood, .mood(let m)):                 mood = m
        case (.energy, .energy(let e)):             energyLevel = e
        case (.medication, .text(let t)):           medication = t
        case (.note, .text(let t)):                 note = t
        case (.customSymptom(let name), _):
            if !loggedCustomSymptoms.contains(name) { loggedCustomSymptoms.append(name) }
        default:
            break   // mismatched pairing — sources build these, so unreachable
        }
    }

    func clear(_ field: ImportObservation.Field) {
        switch field {
        case .flow:             flow = nil
        case .basalTemperature: basalTemperature = nil
        case .cervicalMucus:    cervicalMucus = nil
        case .ovulationTest:    ovulationTestResult = nil
        case .pregnancyTest:    pregnancyTest = nil
        case .sexualActivity:   sexualActivity = nil
        case .symptom(let symptom):
            symptoms.removeAll { $0 == symptom }
            symptomSeverity[symptom.rawValue] = nil
        case .painType(let pain):
            painTypes.removeAll { $0 == pain }
        case .painScore:  pain = nil
        case .mood:       mood = nil
        case .energy:     energyLevel = nil
        case .medication: medication = nil
        case .note:       note = nil
        case .customSymptom(let name):
            loggedCustomSymptoms.removeAll { $0 == name }
        }
    }
}
