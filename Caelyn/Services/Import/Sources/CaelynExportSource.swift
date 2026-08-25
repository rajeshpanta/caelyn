import Foundation

/// Caelyn's own CSV export.
///
/// This one has to be perfect: it is what "export your data" promises, and it is
/// the file she would reach for to move to a new phone or recover from a mistake.
/// Every column `ExportService` writes is read back here.
///
/// Older exports had fewer columns. Nothing is required beyond a date, so a file
/// from any past version still imports — it simply carries less.
enum CaelynExportSource: ImportSource {

    static let id: ImportSourceID = .caelyn

    /// The full set `ExportService.generateCSV` writes today.
    static let knownColumns: Set<String> = [
        "date", "flow", "pain", "pain_types", "symptoms", "mood",
        "energy_level", "medication", "basal_temperature", "cervical_mucus",
        "sexual_activity", "ovulation_test", "pregnancy_test", "custom_symptoms", "note"
    ]

    /// Three Caelyn-specific column names together. `pain_types` and
    /// `custom_symptoms` are not names another tracker happens to pick, and
    /// requiring the combination rules out coincidence.
    static func detect(_ payload: inout ImportPayload) -> ImportDetection {
        let headers = Set(payload.csvHeaders)
        guard headers.contains("date") else { return .no }
        let signature: Set<String> = ["flow", "symptoms", "pain_types"]
        return signature.isSubset(of: headers) ? .certain : .no
    }

    static func parse(_ payload: inout ImportPayload, calendar: Calendar) throws -> ParsedImport {
        guard let rows = payload.csvRows, rows.count >= 2 else { throw ImportSourceError.empty }
        let headers = payload.csvHeaders
        let columns = CSVReader.columnIndex(headers: headers)
        guard let dateIndex = columns["date"] else { throw ImportSourceError.noDateFound }

        let body = Array(rows.dropFirst())
        let dateValues = body.compactMap { $0.indices.contains(dateIndex) ? $0[dateIndex] : nil }
        let dateFormat = ImportValues.detectDateFormat(in: dateValues, calendar: calendar)
        // A column of plain yyyy-MM-dd needs no detected format; anything else
        // must agree on one, or Caelyn cannot read the column safely.
        guard dateFormat != nil || dateValues.contains(where: { ImportValues.isoDayPrefix($0) != nil }) else {
            throw ImportSourceError.noDateFound
        }

        var result = ParsedImport()
        var builder = ObservationBuilder(source: id, calendar: calendar)

        for header in headers where !knownColumns.contains(header) && !header.isEmpty {
            result.noteUnmapped(header)
        }

        for row in body {
            result.rowsRead += 1
            func cell(_ name: String) -> String? {
                guard let index = columns[name], row.indices.contains(index) else { return nil }
                let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
            guard let rawDate = cell("date"),
                  let day = ImportValues.day(from: rawDate, using: dateFormat, calendar: calendar) else {
                result.skip("unreadable date")
                continue
            }

            // Caelyn writes its own raw values, so these match exactly. The
            // tolerant spellings are a fallback for a file edited in a spreadsheet.
            if let raw = cell("flow"), let flow = FlowLevel(rawValue: raw) ?? ImportValues.flow(raw) {
                builder.add(day: day, field: .flow, value: .flow(flow))
            }
            if let raw = cell("pain"), let score = ImportValues.painScore(raw) {
                builder.add(day: day, field: .painScore, value: .painScore(score))
            }
            for raw in ImportValues.splitList(cell("pain_types") ?? "") {
                guard let painType = PainType(rawValue: raw) ?? ImportValues.painType(raw) else {
                    result.noteUnmapped("pain type: \(raw)")
                    continue
                }
                builder.add(day: day, field: .painType(painType), value: .present)
            }
            for raw in ImportValues.splitList(cell("symptoms") ?? "") {
                guard let symptom = Symptom(rawValue: raw) ?? ImportValues.symptom(raw) else {
                    result.noteUnmapped("symptom: \(raw)")
                    continue
                }
                builder.add(day: day, field: .symptom(symptom), value: .symptomSeverity(2))
            }
            for raw in ImportValues.splitList(cell("custom_symptoms") ?? "") {
                builder.add(day: day, field: .customSymptom(raw), value: .present)
            }
            if let raw = cell("mood"), let mood = Mood(rawValue: raw) ?? ImportValues.mood(raw) {
                builder.add(day: day, field: .mood, value: .mood(mood))
            }
            if let raw = cell("energy_level"),
               let energy = EnergyLevel(rawValue: raw) ?? ImportValues.energy(raw) {
                builder.add(day: day, field: .energy, value: .energy(energy))
            }
            if let raw = cell("medication") {
                builder.add(day: day, field: .medication, value: .text(raw))
            }
            if let raw = cell("basal_temperature"), let celsius = ImportValues.temperatureCelsius(raw) {
                builder.add(day: day, field: .basalTemperature, value: .temperature(celsius))
            }
            if let raw = cell("cervical_mucus"),
               let mucus = CervicalMucus(rawValue: raw) ?? ImportValues.mucus(raw) {
                builder.add(day: day, field: .cervicalMucus, value: .mucus(mucus))
            }
            if let raw = cell("sexual_activity"), let value = ImportValues.boolean(raw) {
                builder.add(day: day, field: .sexualActivity, value: .boolean(value))
            }
            if let raw = cell("ovulation_test"),
               let result = OvulationTestResult(rawValue: raw) ?? ImportValues.ovulationTest(raw) {
                builder.add(day: day, field: .ovulationTest, value: .ovulation(result))
            }
            if let raw = cell("pregnancy_test"), let value = ImportValues.boolean(raw) {
                builder.add(day: day, field: .pregnancyTest, value: .boolean(value))
            }
            if let raw = cell("note") {
                builder.add(day: day, field: .note, value: .text(raw))
            }
        }

        result.observations = builder.observations
        return result
    }
}
