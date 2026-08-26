import Foundation

/// Reads a JSON export from an app Caelyn has no verified adapter for.
///
/// It looks for the shape most trackers land on — a list of per-day objects — and
/// maps keys by the same alias table the spreadsheet reader uses. Nothing about
/// the file is assumed: keys it doesn't recognise are reported, and if it can't
/// find a date on an object it skips that object rather than guessing which key
/// might be one.
enum GenericJSONSource: ImportSource {

    static let id: ImportSourceID = .genericJSON

    /// Keys that plausibly hold an array of day records, checked in order.
    private static let containerKeys = ["days", "entries", "logs", "records", "data", "items", "history"]

    private static func rows(in payload: inout ImportPayload) -> [[String: Any]]? {
        if let array = payload.json as? [[String: Any]] { return array }
        guard let object = payload.json as? [String: Any] else { return nil }
        for key in containerKeys {
            if let array = object[key] as? [[String: Any]] { return array }
        }
        // A single nesting level, for exports that wrap everything in one envelope.
        for value in object.values {
            if let nested = value as? [String: Any] {
                for key in containerKeys {
                    if let array = nested[key] as? [[String: Any]] { return array }
                }
            }
        }
        return nil
    }

    private static func dateKey(in rows: [[String: Any]]) -> String? {
        let names = GenericTableSource.aliases.first { $0.field == "date" }!.names
        let sample = rows.prefix(20)
        for key in sample.flatMap({ $0.keys }) {
            let normalized = key.lowercased()
            guard names.contains(normalized) || normalized.contains("date") || normalized == "day" else { continue }
            let values = sample.compactMap { $0[key] as? String }
            if values.count >= min(2, sample.count),
               ImportValues.parseISODate(values[0], calendar: .current) != nil { return key }
        }
        return nil
    }

    /// Never certain — a readable list of dated objects says nothing about which
    /// app wrote it.
    static func detect(_ payload: inout ImportPayload) -> ImportDetection {
        guard let rows = rows(in: &payload), !rows.isEmpty else { return .no }
        return dateKey(in: rows) != nil ? .generic : .no
    }

    static func parse(_ payload: inout ImportPayload, calendar: Calendar) throws -> ParsedImport {
        guard let rows = rows(in: &payload), !rows.isEmpty else { throw ImportSourceError.empty }
        guard let dateKey = dateKey(in: rows) else { throw ImportSourceError.noDateFound }

        var result = ParsedImport()
        var builder = ObservationBuilder(source: id, calendar: calendar)

        // Resolve Caelyn's fields to whatever this file calls them.
        //
        // Sorted, and walked in alias order rather than key order, because a file
        // that carries two names for the same thing — "flow" on some days and
        // "period" on others — would otherwise resolve differently from one run to
        // the next depending on how the keys happened to hash. The same file has to
        // import the same way every time.
        var keyFor: [String: String] = [:]
        var claimed: Set<String> = [dateKey]
        let allKeys = Set(rows.prefix(50).flatMap { $0.keys }).sorted()
        for (field, names) in GenericTableSource.aliases where field != "date" {
            for name in names {
                guard let match = allKeys.first(where: { $0.lowercased() == name && !claimed.contains($0) })
                else { continue }
                keyFor[field] = match
                claimed.insert(match)
                break
            }
        }

        // Only keys Caelyn has no concept for are reported. A second key naming
        // something it already read is a duplicate, not an unknown, and saying
        // "Caelyn doesn't have a place for flow" when flow is exactly what it just
        // imported would be plainly wrong.
        let knownNames = Set(GenericTableSource.aliases.flatMap(\.names))
        for key in allKeys where !claimed.contains(key) && !knownNames.contains(key.lowercased()) {
            result.noteUnmapped(key)
        }

        for row in rows {
            result.rowsRead += 1
            guard let rawDate = row[dateKey] as? String,
                  let day = ImportValues.parseISODate(rawDate, calendar: calendar) else {
                result.skip("unreadable date")
                continue
            }
            func value(_ field: String) -> String? {
                guard let key = keyFor[field], let raw = row[key] else { return nil }
                let text: String
                // Booleans must be recognised before numbers. JSONSerialization
                // hands back `true` as an NSNumber whose stringValue is "1", and
                // "1" reads as a light flow — so a plain "period: true" would
                // have arrived as an intensity the file never stated.
                if let flag = raw as? Bool, CFGetTypeID(raw as CFTypeRef) == CFBooleanGetTypeID() {
                    text = flag ? "true" : "false"
                } else if let string = raw as? String {
                    text = string
                } else if let number = raw as? NSNumber {
                    text = number.stringValue
                } else {
                    return nil
                }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            func list(_ field: String) -> [String] {
                guard let key = keyFor[field] else { return [] }
                if let array = row[key] as? [String] { return array }
                return ImportValues.splitList(value(field) ?? "")
            }

            let before = builder.observations.count
            if let raw = value("flow"), let flow = ImportValues.flow(raw) {
                builder.add(day: day, field: .flow, value: .flow(flow))
            }
            if let raw = value("spotting"), ImportValues.boolean(raw) == true {
                builder.add(day: day, field: .symptom(.irregularBleed), value: .symptomSeverity(1))
            }
            if let raw = value("pain"), let score = ImportValues.painScore(raw) {
                builder.add(day: day, field: .painScore, value: .painScore(score))
            }
            let severity = value("severity").flatMap(ImportValues.severity) ?? 2
            for raw in list("symptoms") {
                if let symptom = ImportValues.symptom(raw) {
                    builder.add(day: day, field: .symptom(symptom), value: .symptomSeverity(severity))
                } else {
                    result.noteUnmapped("symptom: \(raw)")
                }
            }
            for raw in list("painTypes") {
                if let painType = ImportValues.painType(raw) {
                    builder.add(day: day, field: .painType(painType), value: .present)
                }
            }
            if let raw = value("mood"), let mood = ImportValues.mood(raw) {
                builder.add(day: day, field: .mood, value: .mood(mood))
            }
            if let raw = value("energy"), let energy = ImportValues.energy(raw) {
                builder.add(day: day, field: .energy, value: .energy(energy))
            }
            if let raw = value("temperature") {
                if let celsius = ImportValues.temperatureCelsius(raw) {
                    builder.add(day: day, field: .basalTemperature, value: .temperature(celsius))
                } else {
                    result.skip("temperature outside any human range")
                }
            }
            if let raw = value("mucus"), let mucus = ImportValues.mucus(raw) {
                builder.add(day: day, field: .cervicalMucus, value: .mucus(mucus))
            }
            if let raw = value("ovulation"), let test = ImportValues.ovulationTest(raw) {
                builder.add(day: day, field: .ovulationTest, value: .ovulation(test))
            }
            if let raw = value("pregnancy"), let flag = ImportValues.boolean(raw) {
                builder.add(day: day, field: .pregnancyTest, value: .boolean(flag))
            }
            if let raw = value("sex"), let flag = ImportValues.boolean(raw) {
                builder.add(day: day, field: .sexualActivity, value: .boolean(flag))
            }
            if let raw = value("medication") {
                builder.add(day: day, field: .medication, value: .text(raw))
            }
            if let raw = value("note") {
                builder.add(day: day, field: .note, value: .text(raw))
            }
            if builder.observations.count == before { result.skip("nothing Caelyn could use") }
        }

        result.observations = builder.observations
        return result
    }
}
