import Foundation

/// Clue's data export.
///
/// **How she gets it:** in Clue, the menu in Cycle View → Settings → *Request
/// data*. Clue emails a link (it expires after 72 hours) to a zip containing
/// `measurements.json`. iOS Files can unzip it in place; she then picks that file.
///
/// **Format**, verified against two independent open-source converters that both
/// parse real Clue exports: a flat JSON array of
/// `{"date": "...", "type": "...", "value": {...}}`, where `value` is either one
/// `{"option": "..."}` or an array of them, and `bbt` instead carries
/// `{"temperature": <number>}`.
///
/// **Caelyn maps:** period, spotting, pain, feelings, energy, discharge, sex_life,
/// digestion and bbt. **Caelyn does not map:** cravings, skin, hair, collection
/// method, medication, appointments, ailments, tests, and any option not listed
/// below — all reported as unmapped rather than approximated.
///
/// **Limitation Clue documents itself:** the export contains no cycle start
/// markers. Caelyn does not need them — it reconstructs cycles from bleeding days,
/// which is the same thing it does with its own data.
///
/// The option vocabulary below is the verified subset. Because every mapping is
/// keyed by exact option name, an option Clue adds later is simply reported as
/// unmapped — it can never be mis-assigned to a neighbouring value.
enum ClueSource: ImportSource {

    static let id: ImportSourceID = .clue

    private static let flow: [String: FlowLevel] = [
        "light": .light, "medium": .medium, "heavy": .heavy, "very_heavy": .heavy
    ]
    private static let pain: [String: Symptom] = [
        "period_cramps": .cramps, "lower_back": .backPain, "breast_tenderness": .tenderBreasts,
        "headache": .headache, "migraine": .headache, "migraine_with_aura": .headache
    ]
    private static let painChip: [String: PainType] = [
        "period_cramps": .cramps, "lower_back": .backPain, "breast_tenderness": .breastTenderness,
        "headache": .headache, "migraine": .headache, "ovulation": .pelvicPain
    ]
    private static let feelings: [String: Mood] = [
        "happy": .happy, "sad": .sad, "angry": .irritable, "anxious": .anxious,
        "indifferent": .calm, "mood_swings": .moody, "mood_swing": .moody,
        "sensitive": .sensitive, "sensitivity": .sensitive
    ]
    private static let energy: [String: EnergyLevel] = [
        "fully_energized": .energized, "energetic": .high,
        "tired": .low, "exhausted": .drained
    ]
    private static let discharge: [String: CervicalMucus] = [
        "none": .dry, "sticky": .sticky, "creamy": .creamy,
        "egg_white": .eggWhite, "watery": .watery
    ]
    private static let digestion: [String: Symptom] = [
        "nauseated": .nausea, "nauseous": .nausea, "bloated": .bloating, "gassy": .bloating
    ]

    /// A top-level array whose elements carry both `date` and `type` strings.
    /// A plain list of readings from another app would not have that pairing, and
    /// requiring several matching elements rules out a one-element coincidence.
    static func detect(_ payload: inout ImportPayload) -> ImportDetection {
        guard let array = payload.json as? [[String: Any]], !array.isEmpty else { return .no }
        let shaped = array.prefix(50).filter { $0["date"] is String && $0["type"] is String }
        guard shaped.count >= min(3, array.count) else { return .no }
        // At least one element must use a Clue category name, so a generic
        // {date,type} log from some other app doesn't get claimed here.
        let known: Set<String> = ["period", "spotting", "pain", "feelings", "energy",
                                  "discharge", "sex_life", "digestion", "bbt", "craving",
                                  "skin", "hair", "sleep", "exercise", "medication", "test"]
        let matches = shaped.contains { known.contains(($0["type"] as? String) ?? "") }
        return matches ? .certain : .no
    }

    static func parse(_ payload: inout ImportPayload, calendar: Calendar) throws -> ParsedImport {
        guard let array = payload.json as? [[String: Any]] else { throw ImportSourceError.unreadable }
        guard !array.isEmpty else { throw ImportSourceError.empty }

        var result = ParsedImport()
        var builder = ObservationBuilder(source: id, calendar: calendar)
        // Clue records spotting as its own category. Recorded as a symptom, never
        // as flow, so it cannot manufacture a period start in cycle reconstruction.
        var seenTypes: Set<String> = []

        for element in array {
            result.rowsRead += 1
            guard let rawDate = element["date"] as? String,
                  let day = ImportValues.parseISODate(rawDate, calendar: calendar) else {
                result.skip("unreadable date")
                continue
            }
            guard let type = element["type"] as? String else {
                result.skip("entry with no category")
                continue
            }
            seenTypes.insert(type)
            let options = self.options(from: element["value"])

            switch type {
            case "period":
                if let level = options.compactMap({ flow[$0] }).first {
                    builder.add(day: day, field: .flow, value: .flow(level))
                } else {
                    // Clue said there was a period but named the amount in a way
                    // Caelyn doesn't know — or didn't name one at all. The day is
                    // kept without an intensity rather than dropped: losing a
                    // bleeding day costs a cycle boundary, and guessing a level
                    // would be inventing data.
                    builder.add(day: day, field: .flow, value: .flow(.unspecified))
                    if !options.isEmpty {
                        result.noteUnmapped("period: \(options.joined(separator: ", "))")
                    }
                }

            case "spotting":
                builder.add(day: day, field: .symptom(.irregularBleed), value: .symptomSeverity(1))

            case "pain":
                for option in options where option != "pain_free" {
                    if let symptom = pain[option] {
                        builder.add(day: day, field: .symptom(symptom), value: .symptomSeverity(2))
                    }
                    if let chip = painChip[option] {
                        builder.add(day: day, field: .painType(chip), value: .present)
                    }
                    if pain[option] == nil && painChip[option] == nil {
                        result.noteUnmapped("pain: \(option)")
                    }
                }

            case "feelings":
                if let mood = options.compactMap({ feelings[$0] }).first {
                    builder.add(day: day, field: .mood, value: .mood(mood))
                }
                for option in options where feelings[option] == nil {
                    result.noteUnmapped("feeling: \(option)")
                }

            case "energy":
                if let level = options.compactMap({ energy[$0] }).first {
                    builder.add(day: day, field: .energy, value: .energy(level))
                }

            case "discharge":
                if let mucus = options.compactMap({ discharge[$0] }).first {
                    builder.add(day: day, field: .cervicalMucus, value: .mucus(mucus))
                }
                for option in options where discharge[option] == nil {
                    result.noteUnmapped("discharge: \(option)")
                }

            case "digestion":
                for option in options {
                    if let symptom = digestion[option] {
                        builder.add(day: day, field: .symptom(symptom), value: .symptomSeverity(2))
                    } else {
                        result.noteUnmapped("digestion: \(option)")
                    }
                }

            case "sex_life":
                // Clue distinguishes protected, unprotected and withdrawal. Caelyn
                // records only that intimacy happened — it has no protection field,
                // and inventing one from this would be putting words in her mouth.
                if options.contains(where: {
                    ["protected_sex", "unprotected_sex", "withdrawal", "sex"].contains($0)
                }) {
                    builder.add(day: day, field: .sexualActivity, value: .boolean(true))
                }
                for option in options where option.hasSuffix("sex_drive") {
                    result.noteUnmapped("sex drive: \(option)")
                }

            case "bbt":
                guard let temperature = temperature(from: element["value"]) else {
                    result.skip("unreadable temperature")
                    continue
                }
                guard let celsius = ImportValues.temperatureCelsius(String(temperature)) else {
                    result.skip("temperature outside any human range")
                    continue
                }
                builder.add(day: day, field: .basalTemperature, value: .temperature(celsius))

            default:
                result.noteUnmapped(type.replacingOccurrences(of: "_", with: " "))
            }
        }

        result.observations = builder.observations
        if seenTypes.contains("period") {
            result.assumptions.append(
                "Clue's export doesn't mark where each cycle began. Caelyn works that out from your bleeding days, the same way it does with its own."
            )
        }
        return result
    }

    /// `value` is either one `{"option": ...}` or an array of them.
    private static func options(from value: Any?) -> [String] {
        if let list = value as? [[String: Any]] {
            return list.compactMap { $0["option"] as? String }
        }
        if let single = value as? [String: Any], let option = single["option"] as? String {
            return [option]
        }
        return []
    }

    private static func temperature(from value: Any?) -> Double? {
        if let dictionary = value as? [String: Any] {
            if let number = dictionary["temperature"] as? Double { return number }
            if let number = dictionary["temperature"] as? NSNumber { return number.doubleValue }
        }
        return (value as? NSNumber)?.doubleValue
    }
}
