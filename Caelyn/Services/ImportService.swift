import Foundation
import SwiftData

/// CSV data import — the "Switch Kit" for people arriving from another tracker
/// (stand-out plan S5). Two levels of understanding:
///
///  1. **Caelyn's own CSV** (the exact headers ExportService writes): every field
///     round-trips, so an export is a genuine full backup.
///  2. **Generic CSV from other apps / spreadsheets**: finds a date column and a
///     flow/period column by header name, understands common value spellings
///     ("light/medium/heavy/spotting", "yes/true/1", 1–5 scales) and the usual
///     date formats. Enough to reconstruct period history — which is what powers
///     predictions — from a Flo/Clue/spreadsheet export without re-logging years.
///
/// Imports NEVER overwrite data the user logged by hand: fields are only filled
/// where empty, and same-day rows funnel through `CycleStore.entry(for:)`.
@MainActor
enum ImportService {

    struct Result: Equatable {
        var entriesCreated = 0
        var entriesUpdated = 0
        var rowsSkipped = 0
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

    // MARK: - Entry point

    static func importCSV(text: String, into context: ModelContext) throws -> Result {
        let rows = parseCSV(text)
        guard rows.count >= 2 else { throw ImportError.empty }
        let headers = rows[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let body = Array(rows.dropFirst())

        guard let dateIdx = dateColumnIndex(headers: headers, rows: body) else {
            throw ImportError.noDateColumn
        }
        guard let dateFormat = detectDateFormat(rows: body, dateIdx: dateIdx) else {
            throw ImportError.noDateColumn
        }

        let isCaelynFormat = headers.contains("flow") && headers.contains("symptoms") && headers.contains("pain_types")
        var result = Result()

        for row in body {
            guard row.indices.contains(dateIdx),
                  let date = dateFormat.date(from: row[dateIdx].trimmingCharacters(in: .whitespaces))
            else { result.rowsSkipped += 1; continue }

            let before = existingEntry(for: date, in: context) != nil
            let entry = CycleStore.entry(for: date, in: context)

            let changed = isCaelynFormat
                ? applyCaelynRow(row, headers: headers, to: entry)
                : applyGenericRow(row, headers: headers, to: entry)

            if changed {
                entry.updatedAt = .now
                if before { result.entriesUpdated += 1 } else { result.entriesCreated += 1 }
            } else {
                // Nothing usable in the row — remove an entry we just created for it.
                if !before && !entry.hasContent { context.delete(entry) }
                result.rowsSkipped += 1
            }
        }

        guard result.total > 0 else { throw ImportError.empty }
        context.saveOrLog()
        return result
    }

    // MARK: - Caelyn-format rows (full fidelity)

    private static func applyCaelynRow(_ row: [String], headers: [String], to entry: CycleEntry) -> Bool {
        func field(_ name: String) -> String? {
            guard let idx = headers.firstIndex(of: name), row.indices.contains(idx) else { return nil }
            let v = row[idx].trimmingCharacters(in: .whitespaces)
            return v.isEmpty ? nil : v
        }
        var changed = false

        if entry.flow == nil, let f = field("flow").flatMap(FlowLevel.init(rawValue:)) { entry.flow = f; changed = true }
        if entry.pain == nil, let p = field("pain").flatMap(Int.init) { entry.pain = p; changed = true }
        if entry.painTypes.isEmpty, let pt = field("pain_types") {
            entry.painTypes = pt.split(separator: ";").compactMap { PainType(rawValue: String($0)) }
            changed = changed || !entry.painTypes.isEmpty
        }
        if entry.symptoms.isEmpty, let s = field("symptoms") {
            entry.symptoms = s.split(separator: ";").compactMap { Symptom(rawValue: String($0)) }
            changed = changed || !entry.symptoms.isEmpty
        }
        if entry.mood == nil, let m = field("mood").flatMap(Mood.init(rawValue:)) { entry.mood = m; changed = true }
        if entry.energyLevel == nil, let e = field("energy_level").flatMap(EnergyLevel.init(rawValue:)) { entry.energyLevel = e; changed = true }
        if entry.medication == nil, let med = field("medication") { entry.medication = med; changed = true }
        if entry.basalTemperature == nil, let t = field("basal_temperature").flatMap(Double.init) { entry.basalTemperature = t; changed = true }
        if entry.cervicalMucus == nil, let cm = field("cervical_mucus").flatMap(CervicalMucus.init(rawValue:)) { entry.cervicalMucus = cm; changed = true }
        if entry.sexualActivity == nil, let sa = field("sexual_activity") { entry.sexualActivity = (sa == "yes"); changed = true }
        if entry.ovulationTestResult == nil, let o = field("ovulation_test").flatMap(OvulationTestResult.init(rawValue:)) { entry.ovulationTestResult = o; changed = true }
        if entry.pregnancyTest == nil, let pg = field("pregnancy_test") { entry.pregnancyTest = (pg == "positive"); changed = true }
        if entry.loggedCustomSymptoms.isEmpty, let cs = field("custom_symptoms") {
            entry.loggedCustomSymptoms = cs.split(separator: ";").map(String.init)
            changed = changed || !entry.loggedCustomSymptoms.isEmpty
        }
        if entry.note == nil, let n = field("note") { entry.note = n; changed = true }
        return changed
    }

    // MARK: - Generic rows (other apps / spreadsheets)

    /// Headers that commonly mark a flow/period column across tracker exports.
    private static let flowHeaderHints = ["flow", "period", "menstruation", "bleeding", "menses", "period intensity", "flow intensity"]

    private static func applyGenericRow(_ row: [String], headers: [String], to entry: CycleEntry) -> Bool {
        guard entry.flow == nil else { return false }   // never overwrite
        guard let idx = headers.firstIndex(where: { h in flowHeaderHints.contains(where: { h.contains($0) }) }),
              row.indices.contains(idx)
        else { return false }
        guard let flow = flowValue(row[idx].trimmingCharacters(in: .whitespaces).lowercased()) else { return false }
        entry.flow = flow
        return true
    }

    /// Understand the common spellings of flow values across apps.
    static func flowValue(_ raw: String) -> FlowLevel? {
        switch raw {
        case "spotting", "spot":                             return .spotting
        case "light", "low", "1":                            return .light
        case "medium", "moderate", "mid", "2", "true", "yes": return .medium
        case "heavy", "high", "3", "4", "5":                 return .heavy
        default:                                             return nil
        }
    }

    // MARK: - Column & format detection

    private static func dateColumnIndex(headers: [String], rows: [[String]]) -> Int? {
        // Prefer a header literally about dates…
        if let byName = headers.firstIndex(where: { $0 == "date" || $0.contains("date") || $0 == "day" }) {
            return byName
        }
        // …otherwise the first column that parses as a date in the sample rows.
        for idx in headers.indices {
            let sample = rows.prefix(5).compactMap { $0.indices.contains(idx) ? $0[idx] : nil }
            if !sample.isEmpty, detectDateFormat(values: sample) != nil { return idx }
        }
        return nil
    }

    private static let dateFormats = [
        "yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss", "yyyy/MM/dd",
        "MM/dd/yyyy", "dd/MM/yyyy", "MM/dd/yy", "MMM d, yyyy", "d MMM yyyy"
    ]

    private static func detectDateFormat(rows: [[String]], dateIdx: Int) -> DateFormatter? {
        let values = rows.compactMap { row -> String? in
            guard row.indices.contains(dateIdx) else { return nil }
            let v = row[dateIdx].trimmingCharacters(in: .whitespaces)
            return v.isEmpty ? nil : v
        }
        return detectDateFormat(values: values)
    }

    /// Pick the first format that parses EVERY non-empty value — whole-column
    /// consistency avoids the MM/dd vs dd/MM ambiguity biting on partial matches.
    private static func detectDateFormat(values: [String]) -> DateFormatter? {
        guard !values.isEmpty else { return nil }
        for format in dateFormats {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            if values.allSatisfy({ f.date(from: $0) != nil }) { return f }
        }
        return nil
    }

    private static func existingEntry(for date: Date, in context: ModelContext) -> CycleEntry? {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<CycleEntry>(predicate: #Predicate { $0.date == day })
        return try? context.fetch(descriptor).first
    }

    // MARK: - CSV parsing (RFC 4180: quoted fields, escaped quotes, embedded newlines)

    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character? = nil

        func endField() { row.append(field); field = "" }
        func endRow() {
            endField()
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while let ch = pending ?? iterator.next() {
            pending = nil
            if inQuotes {
                if ch == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") }   // escaped quote
                        else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"": inQuotes = true
                case ",":  endField()
                case "\n": endRow()
                case "\r": break   // swallow; \r\n handled by the \n branch
                default:   field.append(ch)
                }
            }
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }
}
