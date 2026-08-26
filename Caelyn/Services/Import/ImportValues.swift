import Foundation

/// Reading dates and values the way other apps actually write them.
///
/// Every function here refuses rather than guesses. A value it doesn't recognise
/// comes back nil and is reported as skipped — because a wrong guess about flow
/// or a temperature is indistinguishable, later, from something she typed.
enum ImportValues {

    // MARK: - Dates

    /// Formats seen across exports and spreadsheet locales, most specific first.
    static let dateFormats = [
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "yyyy/MM/dd",
        "dd/MM/yyyy",
        "MM/dd/yyyy",
        "dd-MM-yyyy",
        "MM/dd/yy",
        "dd.MM.yyyy",
        "MMM d, yyyy",
        "d MMM yyyy"
    ]

    /// Parse a value with a format, and only believe it if it survives being
    /// written back out.
    ///
    /// `DateFormatter` is far looser than it looks. It reads `05.01.2026` with a
    /// slash format, `Jan 5, 2026` with `MM/dd/yyyy`, and — worst of all — turns
    /// `2026-02-30` into March 1st without complaint. Every one of those is a
    /// wrong date that looks perfectly reasonable afterwards. Round-tripping
    /// through the same format is what catches them: a value that formats back
    /// differently was not really that format, and an impossible date never
    /// formats back to the impossible text that produced it.
    static func strictDate(from value: String, format: String, calendar: Calendar) -> Date? {
        let f = formatter(format, calendar: calendar)
        guard let parsed = f.date(from: value) else { return nil }
        guard f.string(from: parsed) == value else { return nil }
        return parsed
    }

    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }

    /// Fraction of a column that must agree on one format before Caelyn will use
    /// it. High enough that a genuinely mixed column is refused, forgiving enough
    /// that a few typos don't cost her the other three years.
    private static let dateFormatAgreement = 0.6

    /// Pick the single format that reads the column, judged across the whole
    /// column rather than row by row.
    ///
    /// The column-wide view is the point: `03/04/2026` is ambiguous alone, and
    /// deciding per row would silently read some of a year as March and the rest
    /// as April. So every candidate format is scored against every value, the
    /// best-scoring one wins, and formats are tried most-specific-first so a
    /// timestamp is never truncated by a plainer pattern that also happens to
    /// match its prefix.
    ///
    /// If nothing reaches agreement — a column with two genuinely different
    /// conventions in it — Caelyn declines rather than reading half of it wrong.
    /// Individual values the winning format can't read are skipped and reported.
    static func detectDateFormat(in values: [String], calendar: Calendar) -> DateFormatter? {
        let candidates = values.compactMap { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !candidates.isEmpty else { return nil }

        // A value that leads with a plain yyyy-MM-dd needs no format detection at
        // all: the day is written right there. Taking it literally is also what
        // keeps a timestamp's zone offset from sliding an entry onto the day
        // before.
        if candidates.allSatisfy({ isoDayPrefix($0) != nil }) { return nil }

        let required = max(1, Int((Double(candidates.count) * dateFormatAgreement).rounded(.up)))
        var best: (format: String, matches: Int)?

        for format in dateFormats {
            let matches = candidates.reduce(into: 0) { total, value in
                if strictDate(from: value, format: format, calendar: calendar) != nil { total += 1 }
            }
            if matches == candidates.count { return formatter(format, calendar: calendar) }
            if matches > (best?.matches ?? 0) { best = (format, matches) }
        }

        guard let best, best.matches >= required else { return nil }
        return formatter(best.format, calendar: calendar)
    }

    /// The `yyyy-MM-dd` a value starts with, if it is a real calendar day.
    /// Returns nil for `2026-02-30`, which is text shaped like a date but isn't one.
    static func isoDayPrefix(_ raw: String) -> DateComponents? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return nil }
        let parts = trimmed.prefix(10).split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), parts[0].count == 4,
              let month = Int(parts[1]), parts[1].count == 2,
              let day = Int(parts[2]), parts[2].count == 2
        else { return nil }
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        return components
    }

    /// Read one value as a calendar day, preferring the literal `yyyy-MM-dd` it
    /// leads with and falling back to the column's detected format.
    static func day(from raw: String, using format: DateFormatter?, calendar: Calendar) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let components = isoDayPrefix(trimmed) {
            guard let date = calendar.date(from: components) else { return nil }
            // Reject a rolled-over date: February 30th parses, but it is not a day.
            let readBack = calendar.dateComponents([.year, .month, .day], from: date)
            guard readBack.year == components.year,
                  readBack.month == components.month,
                  readBack.day == components.day else { return nil }
            return calendar.startOfDay(for: date)
        }
        guard let format else { return nil }
        guard let parsed = format.date(from: trimmed),
              format.string(from: parsed) == trimmed else { return nil }
        return calendar.startOfDay(for: parsed)
    }

    /// Parse a single ISO-ish date, for formats that carry their own timestamps
    /// (Clue and Flo both do) rather than a uniform column.
    static func parseISODate(_ raw: String, calendar: Calendar) -> Date? {
        day(from: raw, using: nil, calendar: calendar)
    }

    // MARK: - Flow

    /// Flow words and scales as other trackers spell them.
    ///
    /// Numeric scales are read as 1-based intensity, which is what every export
    /// checked uses. `0` is treated as "nothing logged", not as spotting, because
    /// a zero in a flow column almost always means an empty day.
    static func flow(_ raw: String) -> FlowLevel? {
        switch normalize(raw) {
        case "spotting", "spot", "verylight", "very_light", "trace":
            return .spotting
        case "light", "low", "1":
            return .light
        case "medium", "moderate", "mid", "normal", "2", "true", "yes", "y", "period":
            return .medium
        case "heavy", "high", "3":
            return .heavy
        case "unspecified", "unknown", "notrecorded", "unrecorded":
            return .unspecified
        case "veryheavy", "very_heavy", "extraheavy", "4", "5":
            return .heavy
        default:
            return nil
        }
    }

    /// True when a flow cell means "no bleeding today" rather than "unknown".
    static func isExplicitlyNoFlow(_ raw: String) -> Bool {
        ["none", "no", "n", "false", "0", "-"].contains(normalize(raw))
    }

    // MARK: - Temperature

    /// Basal temperature, with the unit inferred from the value's own magnitude.
    ///
    /// Human basal temperature occupies two ranges that cannot overlap — roughly
    /// 35-38 °C and 95-100 °F — so a number in the Fahrenheit band is converted
    /// rather than rejected, and anything in neither band is refused outright.
    /// A misread here would land a false thermal shift in her ovulation estimate.
    static func temperatureCelsius(_ raw: String) -> Double? {
        let cleaned = normalize(raw)
            .replacingOccurrences(of: "°", with: "")
            .replacingOccurrences(of: "c", with: "")
            .replacingOccurrences(of: "f", with: "")
        guard let value = Double(cleaned.replacingOccurrences(of: ",", with: ".")),
              value.isFinite else { return nil }

        let saysFahrenheit = raw.lowercased().contains("f")
        let saysCelsius = raw.lowercased().contains("c")

        if saysCelsius, (30...45).contains(value) { return value }
        if saysFahrenheit, (86...113).contains(value) { return (value - 32) * 5 / 9 }
        if (30...45).contains(value) { return value }
        if (86...113).contains(value) { return (value - 32) * 5 / 9 }
        return nil
    }

    // MARK: - Enumerations

    static func mucus(_ raw: String) -> CervicalMucus? {
        switch normalize(raw) {
        case "dry", "none", "nothing":                     return .dry
        case "sticky", "tacky", "pasty":                   return .sticky
        case "creamy", "lotion", "lotiony", "milky":       return .creamy
        case "watery", "wet":                              return .watery
        case "eggwhite", "egg_white", "eggwhitelike",
             "eggwhitecervicalmucus", "ewcm", "stretchy":  return .eggWhite
        default:                                           return nil
        }
    }

    static func ovulationTest(_ raw: String) -> OvulationTestResult? {
        switch normalize(raw) {
        case "negative", "neg", "no", "false":              return .negative
        case "rising", "estrogensurge", "estrogen_surge",
             "high", "peakapproaching":                     return .rising
        case "lhsurge", "lh_surge", "surge", "peak":        return .lhSurge
        case "positive", "pos", "yes", "true":              return .positive
        default:                                            return nil
        }
    }

    static func mood(_ raw: String) -> Mood? {
        switch normalize(raw) {
        case "calm", "balanced", "fine", "indifferent", "neutral", "relaxed": return .calm
        case "happy", "great", "good", "joyful":                              return .happy
        case "energetic", "energized", "fullyenergized":                      return .energetic
        case "focused", "productive":                                         return .focused
        case "sensitive", "sensitivity", "emotional":                         return .sensitive
        case "sad", "down", "depressed", "low":                               return .sad
        case "anxious", "stressed", "worried", "nervous":                     return .anxious
        case "irritable", "angry", "frustrated", "annoyed":                   return .irritable
        case "tired", "exhausted", "sleepy":                                  return .tired
        case "moody", "moodswings", "mood_swings", "moodswing":               return .moody
        case "lowenergy", "low_energy", "drained", "sluggish":                return .lowEnergy
        default:                                                              return nil
        }
    }

    static func energy(_ raw: String) -> EnergyLevel? {
        switch normalize(raw) {
        case "drained", "exhausted", "veryLow".lowercased(), "verylow": return .drained
        case "low", "tired", "sluggish":                                return .low
        case "moderate", "ok", "okay", "medium", "normal", "average":   return .moderate
        case "high", "good":                                            return .high
        case "energized", "energetic", "fullyenergized", "veryhigh":    return .energized
        default:                                                        return nil
        }
    }

    static func boolean(_ raw: String) -> Bool? {
        switch normalize(raw) {
        case "yes", "y", "true", "1", "positive", "pos":  return true
        case "no", "n", "false", "0", "negative", "neg":  return false
        default:                                          return nil
        }
    }

    static func painScore(_ raw: String) -> Int? {
        guard let value = Int(normalize(raw)), (0...10).contains(value) else { return nil }
        return value
    }

    // MARK: - Symptoms

    /// Symptom names as Caelyn spells them, plus the spellings other apps use.
    /// Anything absent is reported as unmapped rather than approximated onto a
    /// neighbouring symptom.
    static func symptom(_ raw: String) -> Symptom? {
        let key = normalize(raw)
        if let exact = Symptom(rawValue: raw.trimmingCharacters(in: .whitespaces)) { return exact }
        switch key {
        case "cramps", "periodcramps", "period_cramps", "abdominalcramps", "stomachcramps": return .cramps
        case "bloating", "bloated", "bloatedness":                     return .bloating
        case "acne", "skinbreakout", "breakout", "spots", "pimples":   return .acne
        case "cravings", "craving", "foodcravings", "appetite":        return .cravings
        case "fatigue", "tired", "exhausted", "exhaustion":            return .fatigue
        case "nausea", "nauseous", "queasy":                           return .nausea
        case "dizziness", "dizzy", "lightheaded":                      return .dizziness
        case "sleepchanges", "sleep", "insomnia", "poorsleep":         return .sleepChanges
        case "tenderbreasts", "breasttenderness", "breast_tenderness",
             "sorebreasts", "breastpain":                              return .tenderBreasts
        case "headache", "migraine", "migrainewithaura",
             "migraine_with_aura":                                     return .headache
        case "backpain", "backache", "lowerback", "lower_back",
             "lowerbackpain":                                          return .backPain
        case "hotflash", "hotflashes", "hotflush":                     return .hotFlash
        case "nightsweats", "nightsweat":                              return .nightSweats
        case "brainfog", "foggy", "difficultyconcentrating":           return .brainFog
        case "vaginaldryness", "dryness":                              return .vaginalDryness
        case "jointpain", "achyjoints":                                return .jointPain
        case "pelvicpressure", "pelvicpain":                           return .pelvicPressure
        case "painfulsex", "dyspareunia":                              return .painfulSex
        case "hairloss", "thinninghair":                               return .hairLoss
        case "irregularbleed", "irregularbleeding", "spottingbetweenperiods",
             "intermenstrualbleeding", "breakthroughbleeding":         return .irregularBleed
        case "weightchanges", "weightgain", "weightloss":              return .weightChanges
        case "heartburn", "acidreflux", "reflux":                      return .heartburn
        case "swelling", "waterretention", "puffiness":                return .swelling
        case "shortbreath", "shortnessofbreath", "breathlessness":     return .shortBreath
        default:                                                       return nil
        }
    }

    static func painType(_ raw: String) -> PainType? {
        switch normalize(raw) {
        case "cramps", "periodcramps", "period_cramps", "abdominalcramps": return .cramps
        case "backpain", "backache", "lowerback", "lower_back":            return .backPain
        case "headache", "migraine":                                       return .headache
        case "breasttenderness", "breast_tenderness", "tenderbreasts",
             "breastpain", "sorebreasts":                                  return .breastTenderness
        case "pelvicpain", "pelvic", "ovulationpain", "ovulation":         return .pelvicPain
        default:                                                           return nil
        }
    }

    /// Severity words as other apps write them, onto Caelyn's 1/2/3.
    static func severity(_ raw: String) -> Int? {
        switch normalize(raw) {
        case "mild", "light", "low", "1":            return 1
        case "moderate", "medium", "2":              return 2
        case "severe", "strong", "high", "3":        return 3
        default:                                     return nil
        }
    }

    // MARK: -

    /// Lowercase, strip whitespace, punctuation and separators — so `Egg White`,
    /// `egg_white` and `eggwhite` are one value rather than three misses.
    static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Split a multi-value cell. Exports variously use `;`, `,` or `|`.
    static func splitList(_ raw: String) -> [String] {
        raw.split(whereSeparator: { $0 == ";" || $0 == "|" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
