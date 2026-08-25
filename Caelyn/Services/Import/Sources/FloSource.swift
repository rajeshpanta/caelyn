import Foundation

/// Flo's data export.
///
/// **How she gets it:** Flo has no in-app download. She opens Flo → her avatar →
/// Help → *Contact us*, and asks for her data; Flo emails a TXT file (readable)
/// and a JSON file (machine-readable). Caelyn reads the JSON. In Anonymous mode
/// the account must be registered first.
///
/// **Format**, verified against two independent open-source converters that parse
/// real Flo exports: a JSON object whose `operationalData.cycles` is an array of
/// `{"period_start_date": ..., "period_end_date": ...}`.
///
/// ## What this honestly recovers, and what it does not
///
/// The verified structure carries **period date ranges and nothing else** — no
/// per-day intensity, no symptoms, no temperatures. Caelyn therefore imports the
/// bleeding days, which is what actually drives predictions, and says plainly that
/// it is doing so. It records those days as medium, because `FlowLevel` has no
/// "unspecified" and a period day with no intensity still has to be a period day
/// — and it tells her that in the preview rather than letting her discover it.
///
/// Any other section of a Flo export is counted and reported as unmapped rather
/// than parsed on a guess. If Flo's export turns out to carry symptom history in a
/// shape that can be verified, it belongs here — added deliberately, with the same
/// evidence, not inferred from a key name that looks about right.
enum FloSource: ImportSource {

    static let id: ImportSourceID = .flo

    private static func cycles(in payload: inout ImportPayload) -> [[String: Any]]? {
        guard let root = payload.json as? [String: Any],
              let operational = root["operationalData"] as? [String: Any],
              let cycles = operational["cycles"] as? [[String: Any]]
        else { return nil }
        return cycles
    }

    /// `operationalData.cycles` carrying `period_start_date` is a structure no
    /// other export shares, so recognising it cannot be a coincidence.
    static func detect(_ payload: inout ImportPayload) -> ImportDetection {
        guard let cycles = cycles(in: &payload), !cycles.isEmpty else { return .no }
        let dated = cycles.prefix(20).contains { $0["period_start_date"] is String }
        return dated ? .certain : .no
    }

    static func parse(_ payload: inout ImportPayload, calendar: Calendar) throws -> ParsedImport {
        guard let cycles = cycles(in: &payload) else { throw ImportSourceError.unreadable }
        guard !cycles.isEmpty else { throw ImportSourceError.empty }

        var result = ParsedImport()
        var builder = ObservationBuilder(source: id, calendar: calendar)

        if let root = payload.json as? [String: Any] {
            for key in root.keys where key != "operationalData" {
                result.noteUnmapped(key)
            }
            if let operational = root["operationalData"] as? [String: Any] {
                for key in operational.keys where key != "cycles" {
                    result.noteUnmapped(key)
                }
            }
        }

        for cycle in cycles {
            result.rowsRead += 1
            guard let rawStart = cycle["period_start_date"] as? String,
                  let start = ImportValues.parseISODate(rawStart, calendar: calendar) else {
                result.skip("cycle with no start date")
                continue
            }
            // A missing or nonsensical end date means a one-day period rather than
            // a discarded cycle — the start date is the part predictions need.
            let end: Date = {
                guard let rawEnd = cycle["period_end_date"] as? String,
                      let parsed = ImportValues.parseISODate(rawEnd, calendar: calendar),
                      parsed >= start
                else { return start }
                return parsed
            }()

            let span = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            // A "period" longer than this is a data error, not a period. Writing it
            // out would fabricate weeks of bleeding days and wreck cycle averages.
            guard span <= 15 else {
                result.skip("period longer than any real one")
                continue
            }

            for offset in 0..<span {
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                builder.add(day: day, field: .flow, value: .flow(.medium))
            }
        }

        result.observations = builder.observations
        if !builder.observations.isEmpty {
            result.assumptions.append(
                "Flo's export records the dates of your periods but not how heavy each day was, so Caelyn brings the days across as medium. You can change any of them."
            )
        }
        return result
    }
}
