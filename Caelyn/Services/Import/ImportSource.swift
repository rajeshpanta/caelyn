import Foundation

/// Which app a file came from.
///
/// Cases exist only where Caelyn can genuinely read the format. A source is not
/// listed because it is popular — it is listed because its export has been
/// verified and parsed. Claiming support Caelyn does not have would be worse than
/// offering none: she would follow the instructions, hand over years of history,
/// and get silence.
enum ImportSourceID: String, CaseIterable, Identifiable, Sendable {
    case caelyn
    case clue
    case flo
    case genericCSV
    case genericJSON
    /// Not a file format — the history already on her iPhone. It shares this type
    /// so both routes produce the same preview and the same undo, and it is kept
    /// out of `detectionOrder` because no file can ever be it.
    case appleHealth

    var id: String { rawValue }

    /// Name shown to her, and recorded as provenance on every value imported.
    var displayName: String {
        switch self {
        case .caelyn:      return "Caelyn backup"
        case .clue:        return "Clue"
        case .flo:         return "Flo"
        case .genericCSV:  return "Spreadsheet"
        case .genericJSON: return "Another app"
        case .appleHealth: return "Apple Health"
        }
    }

    /// Order matters: a specific format must get the chance to claim a file
    /// before a generic reader takes it. Caelyn's own export is first because it
    /// is the only one that can be recognised with certainty.
    static var detectionOrder: [ImportSourceID] {
        [.caelyn, .clue, .flo, .genericCSV, .genericJSON]
    }
}

/// How sure a source is that a file is its own.
///
/// There is deliberately no "probably". Health history mis-mapped from a
/// misidentified file is silent, plausible-looking corruption — so a source
/// either recognises a file by structure it could not have by coincidence, or it
/// declines and lets the generic reader do the honest, conservative thing.
enum ImportDetection: Equatable, Sendable {
    /// Structural evidence that is not reachable by accident.
    case certain
    /// Readable, but only as a generic table or document.
    case generic
    case no
}

/// One app's export format.
///
/// Adding a source means writing a detector and a parser and nothing else — no
/// merge rules, no conflict handling, no duplicate logic. All of that lives once,
/// in `ImportReconciler`, which is what keeps this from turning into a pile of
/// bespoke importers that each treat her data slightly differently.
protocol ImportSource {
    static var id: ImportSourceID { get }

    /// Does this file belong to this source? Must be deterministic, must run on
    /// structure rather than filename, and must be cheap enough to run for every
    /// candidate source on every file.
    static func detect(_ payload: inout ImportPayload) -> ImportDetection

    /// Turn the file into observations. Throwing is for a file that cannot be
    /// read at all; a single bad row is reported in `ParsedImport`, never thrown,
    /// so one malformed line can't cost her the other three years.
    static func parse(_ payload: inout ImportPayload, calendar: Calendar) throws -> ParsedImport
}

/// What a source found, before any merge decisions are made.
struct ParsedImport: Sendable {
    var observations: [ImportObservation] = []

    /// Columns or keys Caelyn saw and chose not to map. Surfaced so she can tell
    /// the difference between "Caelyn ignored my mood data" and "Caelyn didn't
    /// find any" — never guessed at.
    var unmappedFields: [String: Int] = [:]

    /// Things the format forced Caelyn to assume, in plain words. Shown before
    /// she confirms, because an assumption she can't see is one she can't refuse.
    var assumptions: [String] = []

    var rowsRead = 0
    var rowsSkipped = 0
    /// Why rows were skipped, keyed by a short reason for display.
    var skipReasons: [String: Int] = [:]

    mutating func skip(_ reason: String) {
        rowsSkipped += 1
        skipReasons[reason, default: 0] += 1
    }

    mutating func noteUnmapped(_ field: String) {
        unmappedFields[field, default: 0] += 1
    }
}

enum ImportSourceError: Error, LocalizedError {
    case unreadable
    case empty
    case noDateFound
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "That file couldn't be opened. If it came out of another app as a zip, unzip it first and pick the file inside."
        case .empty:
            return "That file is empty."
        case .noDateFound:
            return "Caelyn couldn't find any dates in that file, so there's nothing to place on your calendar."
        case .unsupported:
            return "Caelyn doesn't recognise that file yet. It reads Caelyn backups, Clue and Flo exports, and most spreadsheets saved as CSV."
        }
    }
}
