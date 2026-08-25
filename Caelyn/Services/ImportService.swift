import Foundation
import SwiftData

/// The original "Import data" entry point, now a thin façade over the shared
/// import pipeline.
///
/// It keeps its old shape because Settings and the existing tests depend on it,
/// but it no longer contains any parsing or merge logic of its own: detection is
/// `ImportPlanner`'s job, mapping is a source adapter's, and deciding what may
/// overwrite what is `ImportReconciler`'s. One conflict engine, one set of rules,
/// whether data arrives from Apple Health or from a file.
///
/// Prefer `ImportPlanner.plan` + `.commit` for anything new — that pair can show
/// her what will happen before it does. This one commits immediately, which is
/// what the current Settings row has always done.
@MainActor
enum ImportService {

    struct Result: Equatable {
        var entriesCreated = 0
        var entriesUpdated = 0
        var rowsSkipped = 0
        /// Values Caelyn kept because she had logged them herself.
        var keptYourValue = 0
        var total: Int { entriesCreated + entriesUpdated }
    }

    enum ImportError: Error, LocalizedError {
        case unreadable
        case noDateColumn
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable:   return "That file couldn't be read as CSV text."
            case .noDateColumn: return "No date column was found. The file needs a column of dates (like 2026-05-14)."
            case .empty:        return "No rows with usable data were found in that file."
            }
        }
    }

    /// Read a CSV — Caelyn's own export or another app's — and merge it in.
    static func importCSV(
        text: String,
        into context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current,
        today: Date = .now
    ) throws -> Result {
        guard let data = text.data(using: .utf8) else { throw ImportError.unreadable }
        return try importFile(named: "import.csv", data: data, into: context,
                              ledger: ledger, calendar: calendar, today: today)
    }

    /// Read any supported file. Errors are translated back into this type's own
    /// cases so existing callers keep the messages they already show.
    static func importFile(
        named filename: String,
        data: Data,
        into context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current,
        today: Date = .now
    ) throws -> Result {
        var payload = ImportPayload(filename: filename, data: data)

        let preview: ImportPreview
        do {
            preview = try ImportPlanner.plan(payload: &payload, context: context,
                                             ledger: ledger, calendar: calendar, today: today)
        } catch ImportSourceError.noDateFound {
            throw ImportError.noDateColumn
        } catch ImportSourceError.empty {
            throw ImportError.empty
        } catch {
            throw ImportError.unreadable
        }

        // A file Caelyn could read but that changes nothing is the same outcome
        // the old importer reported: there was nothing here to bring over.
        guard preview.hasChanges else { throw ImportError.empty }

        // Which days already existed, so "new" and "merged" mean what they used to.
        let existingDays = Set(((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? [])
            .map { calendar.startOfDay(for: $0.date) })

        let outcome = ImportPlanner.commit(preview, context: context, ledger: ledger, calendar: calendar)
        guard outcome.succeeded else { throw ImportError.unreadable }

        var changedDays: Set<Date> = []
        for decision in preview.decisions {
            switch decision.action {
            case .fill, .update, .clear: changedDays.insert(decision.day)
            default: break
            }
        }

        return Result(
            entriesCreated: changedDays.subtracting(existingDays).count,
            entriesUpdated: changedDays.intersection(existingDays).count,
            rowsSkipped: preview.parsed.rowsSkipped + outcome.summary.rejected,
            keptYourValue: outcome.summary.keptUserValue
        )
    }

    // MARK: - Compatibility

    /// Kept for the existing tests and any caller that still reaches for them.
    static func parseCSV(_ text: String) -> [[String]] { CSVReader.parse(text) }
    static func flowValue(_ raw: String) -> FlowLevel? { ImportValues.flow(raw) }
}
