import Foundation

/// Reads any table with a date column — a spreadsheet she keeps herself, or an
/// export from an app Caelyn has no dedicated adapter for.
///
/// This is the honest fallback, and it is what makes "another app" a real answer
/// rather than a dead end. It matches columns by name against a list of spellings
/// and **ignores everything it doesn't recognise**, reporting those columns so she
/// can see what was left behind instead of wondering.
enum GenericTableSource: ImportSource {

    static let id: ImportSourceID = .genericCSV

    /// Column spellings per Caelyn field. Order within a list is preference:
    /// the leftmost matching header in the file wins.
    static let aliases: [(field: String, names: [String])] = [
        ("date",        ["date", "day", "entry date", "log date", "datum", "fecha", "timestamp", "date_time"]),
        ("flow",        ["flow", "menstrual flow", "period", "bleeding", "flow level", "period flow",
                         "bleeding.value", "menstruation", "flow_intensity", "intensity"]),
        ("spotting",    ["spotting", "spot", "intermenstrual bleeding", "breakthrough bleeding"]),
        ("pain",        ["pain", "pain level", "pain score", "cramps level", "pain_level"]),
        ("painTypes",   ["pain types", "pain_types", "pain type", "where it hurts"]),
        ("symptoms",    ["symptoms", "symptom", "physical symptoms", "signs", "tags"]),
        ("severity",    ["severity", "symptom severity", "symptom_severity"]),
        ("mood",        ["mood", "moods", "emotion", "emotions", "feelings", "mental"]),
        ("energy",      ["energy", "energy level", "energy_level"]),
        ("temperature", ["temperature", "bbt", "basal temperature", "basal body temperature",
                         "basal_temperature", "temp", "temperature.value", "waking temperature"]),
        ("mucus",       ["cervical mucus", "cervical_mucus", "mucus", "discharge", "cm",
                         "mucus.value", "cervical fluid"]),
        ("ovulation",   ["ovulation test", "ovulation_test", "lh", "lh test", "opk",
                         "ovulation", "lh_test", "ovulation test result"]),
        ("pregnancy",   ["pregnancy test", "pregnancy_test", "hcg", "pregnancy test result"]),
        ("sex",         ["sexual activity", "sexual_activity", "sex", "intercourse", "intimacy"]),
        ("medication",  ["medication", "medications", "meds", "pill", "medicine"]),
        ("note",        ["note", "notes", "comment", "comments", "journal", "diary", "note.value"])
    ]

    /// Generic, never certain: a table with dates is readable, but nothing about
    /// it identifies an app. Claiming certainty here is exactly how a file gets
    /// mis-mapped.
    static func detect(_ payload: inout ImportPayload) -> ImportDetection {
        guard let rows = payload.csvRows, rows.count >= 2 else { return .no }
        return dateColumn(in: &payload, rows: rows) != nil ? .generic : .no
    }

    /// Find the date column: by header name first, then — for a file with no
    /// usable header at all — by finding a column whose values all parse as dates.
    private static func dateColumn(in payload: inout ImportPayload, rows: [[String]]) -> Int? {
        let headers = payload.csvHeaders
        let dateNames = aliases.first { $0.field == "date" }!.names
        if let named = headers.firstIndex(where: { header in
            dateNames.contains(header) || header.contains("date")
        }) { return named }

        let body = rows.dropFirst().prefix(20)
        for column in headers.indices {
            let sample = body.compactMap { $0.indices.contains(column) ? $0[column] : nil }
            guard sample.count >= 2 else { continue }
            if ImportValues.detectDateFormat(in: Array(sample), calendar: .current) != nil { return column }
        }
        return nil
    }

    static func parse(_ payload: inout ImportPayload, calendar: Calendar) throws -> ParsedImport {
        guard let rows = payload.csvRows, rows.count >= 2 else { throw ImportSourceError.empty }
        let headers = payload.csvHeaders
        guard let dateIndex = dateColumn(in: &payload, rows: rows) else { throw ImportSourceError.noDateFound }

        let body = Array(rows.dropFirst())
        let dateValues = body.compactMap { $0.indices.contains(dateIndex) ? $0[dateIndex] : nil }
        let dateFormat = ImportValues.detectDateFormat(in: dateValues, calendar: calendar)
        // A column of plain yyyy-MM-dd needs no detected format; anything else
        // must agree on one, or Caelyn cannot read the column safely.
        guard dateFormat != nil || dateValues.contains(where: { ImportValues.isoDayPrefix($0) != nil }) else {
            throw ImportSourceError.noDateFound
        }

        // Resolve each Caelyn field to at most one column. Exact header names win;
        // failing that, a header that *contains* a known name is accepted, which is
        // what catches real-world spellings like "Period Intensity" or
        // "Basal temperature (C)". A column already claimed by another field is
        // never taken twice.
        // Every column that names a field, left to right — not just the first.
        //
        // A sheet may carry "Flow" for some rows and "Period" for others, or a
        // tidy column beside a messy one. Both are read and each row uses whichever
        // it actually fills in; keeping only one would quietly discard the rest.
        var columnsFor: [String: [Int]] = ["date": [dateIndex]]
        var taken: Set<Int> = [dateIndex]

        func claim(_ field: String, where matches: (String) -> Bool) {
            for index in headers.indices where !taken.contains(index) && matches(headers[index]) {
                columnsFor[field, default: []].append(index)
                taken.insert(index)
            }
        }

        // Exact header names first, across every field, so a file that spells a
        // column exactly right never loses it to another field's loose match.
        for (field, names) in aliases where field != "date" {
            claim(field) { names.contains($0) }
        }
        for (field, names) in aliases where field != "date" {
            claim(field) { header in names.contains { header.contains($0) } }
        }

        var result = ParsedImport()

        // Columns Caelyn has no concept for. A second column naming something it
        // already read is a duplicate, not an unknown, so it is left out of this
        // list rather than reported as having nowhere to go.
        let claimedColumns = Set(columnsFor.values.flatMap { $0 })
        let knownNames = Set(aliases.flatMap(\.names))
        for (index, header) in headers.enumerated()
        where !claimedColumns.contains(index) && !header.isEmpty && !knownNames.contains(header) {
            result.noteUnmapped(header)
        }

        var builder = ObservationBuilder(source: id, calendar: calendar)

        for row in body {
            result.rowsRead += 1
            func cell(_ field: String) -> String? {
                // Leftmost column of this field that the row actually fills in.
                for index in columnsFor[field] ?? [] where row.indices.contains(index) {
                    let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty { return value }
                }
                return nil
            }
            guard let rawDate = cell("date"),
                  let day = ImportValues.day(from: rawDate, using: dateFormat, calendar: calendar) else {
                result.skip("unreadable date")
                continue
            }
            let before = builder.observations.count

            if let raw = cell("flow") {
                if let flow = ImportValues.flow(raw) {
                    builder.add(day: day, field: .flow, value: .flow(flow))
                } else if !ImportValues.isExplicitlyNoFlow(raw) {
                    result.skip("unrecognised flow value")
                }
            }
            // Spotting is a symptom, never flow: PredictionEngine counts any flow
            // day as bleeding, so a spotting column written into flow would invent
            // period starts and distort every cycle length she has.
            if let raw = cell("spotting"), ImportValues.boolean(raw) == true {
                builder.add(day: day, field: .symptom(.irregularBleed), value: .symptomSeverity(1))
            }
            if let raw = cell("pain"), let score = ImportValues.painScore(raw) {
                builder.add(day: day, field: .painScore, value: .painScore(score))
            }
            for raw in ImportValues.splitList(cell("painTypes") ?? "") {
                if let painType = ImportValues.painType(raw) {
                    builder.add(day: day, field: .painType(painType), value: .present)
                } else {
                    result.noteUnmapped("pain type: \(raw)")
                }
            }
            // One severity column applies to every symptom in the row — that is
            // how the exports that carry it are shaped.
            let rowSeverity = cell("severity").flatMap(ImportValues.severity) ?? 2
            for raw in ImportValues.splitList(cell("symptoms") ?? "") {
                if let symptom = ImportValues.symptom(raw) {
                    builder.add(day: day, field: .symptom(symptom), value: .symptomSeverity(rowSeverity))
                } else {
                    result.noteUnmapped("symptom: \(raw)")
                }
            }
            if let raw = cell("mood") {
                if let mood = ImportValues.splitList(raw).compactMap(ImportValues.mood).first {
                    builder.add(day: day, field: .mood, value: .mood(mood))
                } else {
                    result.noteUnmapped("mood: \(raw)")
                }
            }
            if let raw = cell("energy"), let energy = ImportValues.energy(raw) {
                builder.add(day: day, field: .energy, value: .energy(energy))
            }
            if let raw = cell("temperature") {
                if let celsius = ImportValues.temperatureCelsius(raw) {
                    builder.add(day: day, field: .basalTemperature, value: .temperature(celsius))
                } else {
                    result.skip("temperature outside any human range")
                }
            }
            if let raw = cell("mucus"), let mucus = ImportValues.mucus(raw) {
                builder.add(day: day, field: .cervicalMucus, value: .mucus(mucus))
            }
            if let raw = cell("ovulation"), let test = ImportValues.ovulationTest(raw) {
                builder.add(day: day, field: .ovulationTest, value: .ovulation(test))
            }
            if let raw = cell("pregnancy"), let value = ImportValues.boolean(raw) {
                builder.add(day: day, field: .pregnancyTest, value: .boolean(value))
            }
            if let raw = cell("sex"), let value = ImportValues.boolean(raw) {
                builder.add(day: day, field: .sexualActivity, value: .boolean(value))
            }
            if let raw = cell("medication") {
                builder.add(day: day, field: .medication, value: .text(raw))
            }
            if let raw = cell("note") {
                builder.add(day: day, field: .note, value: .text(raw))
            }

            if builder.observations.count == before { result.skip("nothing Caelyn could use") }
        }

        result.observations = builder.observations
        return result
    }
}
