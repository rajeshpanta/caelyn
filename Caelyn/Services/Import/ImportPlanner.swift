import Foundation
import SwiftData

/// Turns a file she picked into a plan she can look at and agree to.
///
/// The whole point of the split is that **nothing is written until she says so**.
/// `plan` reads the file, works out every change, and returns a description of it.
/// `commit` is a separate call. Walking away between the two changes nothing,
/// because nothing has happened yet.
@MainActor
enum ImportPlanner {

    // MARK: - Detection

    struct Identification: Sendable {
        let source: ImportSourceID
        let confidence: ImportDetection
        /// Sources that also recognised the file. More than one certain match is
        /// treated as no match at all.
        let alsoMatched: [ImportSourceID]
    }

    /// A file that has been read and understood, but not yet compared against
    /// anything she has logged. Carries no database state, so it can be produced
    /// off the main thread and handed back.
    struct ReadFile: Sendable {
        let identification: Identification
        let parsed: ParsedImport
    }

    nonisolated private static func detector(for id: ImportSourceID) -> (inout ImportPayload) -> ImportDetection {
        switch id {
        case .caelyn:      return CaelynExportSource.detect
        case .clue:        return ClueSource.detect
        case .flo:         return FloSource.detect
        case .genericCSV:  return GenericTableSource.detect
        case .genericJSON: return GenericJSONSource.detect
        // Never a file, so nothing can be detected as it.
        case .appleHealth: return { _ in .no }
        }
    }

    nonisolated private static func parser(for id: ImportSourceID) -> (inout ImportPayload, Calendar) throws -> ParsedImport {
        switch id {
        case .caelyn:      return CaelynExportSource.parse
        case .clue:        return ClueSource.parse
        case .flo:         return FloSource.parse
        case .genericCSV:  return GenericTableSource.parse
        case .genericJSON: return GenericJSONSource.parse
        case .appleHealth: return { _, _ in throw ImportSourceError.unsupported }
        }
    }

    /// Work out which app wrote a file, from its structure alone.
    ///
    /// Two rules keep this safe. A source must recognise structure it could not
    /// match by coincidence before it is believed. And if two sources both claim
    /// certainty, neither is trusted — Caelyn falls back to reading the file as a
    /// plain table or document, which maps less but cannot mis-map. Guessing wrong
    /// here would write years of history into the wrong fields, quietly.
    nonisolated static func identify(_ payload: inout ImportPayload) throws -> Identification {
        guard !payload.isEmpty else { throw ImportSourceError.empty }

        var certain: [ImportSourceID] = []
        var generic: [ImportSourceID] = []
        for id in ImportSourceID.detectionOrder {
            switch detector(for: id)(&payload) {
            case .certain: certain.append(id)
            case .generic: generic.append(id)
            case .no:      continue
            }
        }

        if certain.count == 1 {
            return Identification(source: certain[0], confidence: .certain, alsoMatched: [])
        }
        if certain.count > 1 {
            // Ambiguous. Read it generically rather than picking a winner.
            if let fallback = generic.first {
                return Identification(source: fallback, confidence: .generic, alsoMatched: certain)
            }
            throw ImportSourceError.unsupported
        }
        if let fallback = generic.first {
            return Identification(source: fallback, confidence: .generic, alsoMatched: [])
        }
        throw ImportSourceError.unsupported
    }

    /// Identify and parse a file. No database, no main thread — reading a
    /// five-year export is real work, and doing it on the main thread would freeze
    /// the screen she is looking at.
    nonisolated static func read(
        filename: String,
        data: Data,
        calendar: Calendar = .current
    ) throws -> ReadFile {
        var payload = ImportPayload(filename: filename, data: data)
        let identification = try identify(&payload)
        let parsed = try parser(for: identification.source)(&payload, calendar)
        return ReadFile(identification: identification, parsed: parsed)
    }

    /// Read a file off the main thread, then work out what it would change.
    ///
    /// The split matters: parsing is CPU-bound and belongs on a background thread,
    /// while comparing against her existing entries needs the store and therefore
    /// the main actor. Doing both in one place would either block the UI or touch
    /// SwiftData from the wrong thread.
    static func plan(
        filename: String,
        data: Data,
        context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current,
        today: Date = .now
    ) async throws -> ImportPreview {
        let file = try await Task.detached(priority: .userInitiated) {
            try read(filename: filename, data: data, calendar: calendar)
        }.value
        return plan(file, context: context, ledger: ledger, calendar: calendar, today: today)
    }

    /// Compare an already-read file against what she has logged.
    static func plan(
        _ file: ReadFile,
        context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current,
        today: Date = .now
    ) -> ImportPreview {
        let identification = file.identification
        let parsed = file.parsed

        guard !parsed.observations.isEmpty else {
            return ImportPreview(
                source: identification.source,
                confidence: identification.confidence,
                ambiguousWith: identification.alsoMatched,
                summary: ImportReconciler.Summary(),
                parsed: parsed,
                decisions: [],
                batchID: UUID()
            )
        }

        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Date: CycleEntry] = [:]
        for entry in entries { byDay[calendar.startOfDay(for: entry.date)] = entry }

        let decisions = ImportReconciler.plan(
            observations: parsed.observations,
            currentValue: { day, field in byDay[calendar.startOfDay(for: day)]?.value(for: field) },
            ledger: ledger,
            ownBundleID: Bundle.main.bundleIdentifier ?? "",
            acceptOwnSource: true,
            calendar: calendar,
            today: today
        )

        return ImportPreview(
            source: identification.source,
            confidence: identification.confidence,
            ambiguousWith: identification.alsoMatched,
            summary: ImportReconciler.summarize(decisions),
            parsed: parsed,
            decisions: decisions,
            batchID: UUID()
        )
    }

    // MARK: - Plan

    /// Read the file and decide everything, without writing anything.
    static func plan(
        payload: inout ImportPayload,
        context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current,
        today: Date = .now
    ) throws -> ImportPreview {
        let identification = try identify(&payload)
        let parsed = try parser(for: identification.source)(&payload, calendar)

        guard !parsed.observations.isEmpty else {
            // The file was readable but held nothing Caelyn could place on a
            // calendar. That is a result worth reporting, not an error to throw.
            return ImportPreview(
                source: identification.source,
                confidence: identification.confidence,
                ambiguousWith: identification.alsoMatched,
                summary: ImportReconciler.Summary(),
                parsed: parsed,
                decisions: [],
                batchID: UUID()
            )
        }

        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Date: CycleEntry] = [:]
        for entry in entries { byDay[calendar.startOfDay(for: entry.date)] = entry }

        let decisions = ImportReconciler.plan(
            observations: parsed.observations,
            currentValue: { day, field in byDay[calendar.startOfDay(for: day)]?.value(for: field) },
            ledger: ledger,
            // A file is never Caelyn's own live source, so nothing here can be
            // mistaken for a sync loop.
            ownBundleID: Bundle.main.bundleIdentifier ?? "",
            acceptOwnSource: true,
            calendar: calendar,
            today: today
        )

        return ImportPreview(
            source: identification.source,
            confidence: identification.confidence,
            ambiguousWith: identification.alsoMatched,
            summary: ImportReconciler.summarize(decisions),
            parsed: parsed,
            decisions: decisions,
            batchID: UUID()
        )
    }

    // MARK: - Commit

    /// Apply a plan she has agreed to.
    ///
    /// Re-checks every decision against the live store as it writes, so a value
    /// logged while the preview was on screen still wins. Rolls back completely if
    /// the save fails — a half-written import is not something anyone should have
    /// to reason about afterwards.
    @discardableResult
    static func commit(
        _ preview: ImportPreview,
        context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current
    ) -> ImportReconciler.CommitResult {
        let result = ImportReconciler.commit(
            preview.decisions,
            into: context,
            ledger: ledger,
            batchID: preview.batchID,
            calendar: calendar
        )
        guard result.succeeded, result.summary.changeCount > 0 else { return result }

        ledger.addBatch(ImportLedger.Batch(
            id: preview.batchID,
            sourceID: preview.source.rawValue,
            sourceName: preview.source.displayName,
            importedAt: Date(),
            valuesWritten: result.summary.changeCount,
            daysAffected: result.summary.daysAffected
        ))
        ledger.save()
        return result
    }

    // MARK: - Undo

    /// Take back an import, and nothing else.
    ///
    /// Only values this import wrote **and that Caelyn still owns** are removed. A
    /// value she edited afterwards is hers and stays; a value a later import
    /// replaced belongs to that import and stays; a day that had her own data on it
    /// keeps everything except what this import added. Days left completely empty
    /// are removed so undo doesn't leave blank rows behind.
    @discardableResult
    static func undo(
        batchID: UUID,
        context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current
    ) -> ImportReconciler.CommitResult {
        let claims = ledger.claims(inBatch: batchID)
        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Date: CycleEntry] = [:]
        for entry in entries { byDay[calendar.startOfDay(for: entry.date)] = entry }

        var decisions: [ImportReconciler.Decision] = []
        for claim in claims {
            guard let field = ImportObservation.Field(ledgerKey: claim.fieldKey),
                  let day = dayFromKey(claim.dayKey, calendar: calendar),
                  let stored = byDay[day]?.value(for: field),
                  // She changed it since — it is hers, and undo does not touch it.
                  stored.ledgerValue == claim.importedValue
            else { continue }
            decisions.append(ImportReconciler.Decision(day: day, field: field, action: .clear, observation: nil))
        }

        let result = ImportReconciler.commit(decisions, into: context, ledger: ledger, batchID: nil, calendar: calendar)
        if result.succeeded {
            ledger.removeBatch(id: batchID)
            ledger.save()
        }
        return result
    }

    private static func dayFromKey(_ dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]; components.month = parts[1]; components.day = parts[2]
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }
}
