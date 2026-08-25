import Foundation

/// One value, for one calendar day, for one Caelyn field, traced back to the
/// exact record it came from.
///
/// This is the *only* currency the merge engine speaks. An Apple Health sample, a
/// row of a Clue export and a line of a spreadsheet all normalize into an
/// `ImportObservation`, so there is a single reconciliation policy to reason about
/// and to test — rather than one merge path per source, each drifting on its own.
struct ImportObservation: Equatable {

    /// Which Caelyn field an observation lands in.
    ///
    /// Deliberately field-level rather than entry-level: provenance and conflict
    /// resolution have to be per-field, because a single day routinely mixes
    /// hand-logged values with imported ones (she logs her flow in Caelyn, her
    /// ring writes the temperature).
    enum Field: Hashable {
        case flow
        case basalTemperature
        case cervicalMucus
        case ovulationTest
        case pregnancyTest
        case sexualActivity
        case symptom(Symptom)
        case painType(PainType)
        /// The 0-10 slider. Only ever filled by a source that genuinely carries a
        /// comparable scale — never derived from a severity word.
        case painScore
        case mood
        case energy
        case medication
        case note
        /// One of her own named symptoms, matched by name.
        case customSymptom(String)

        /// Stable string key for the on-disk ledger. Must never change for an
        /// existing case or previously-recorded provenance is orphaned (which
        /// fails safe — the value simply becomes user-owned — but loses history).
        var ledgerKey: String {
            switch self {
            case .flow:             return "flow"
            case .basalTemperature: return "bbt"
            case .cervicalMucus:    return "mucus"
            case .ovulationTest:    return "lh"
            case .pregnancyTest:    return "pregtest"
            case .sexualActivity:   return "sex"
            case .symptom(let s):   return "symptom:\(s.rawValue)"
            case .painType(let p):  return "pain:\(p.rawValue)"
            case .painScore:        return "painscore"
            case .mood:             return "mood"
            case .energy:           return "energy"
            case .medication:       return "medication"
            case .note:             return "note"
            case .customSymptom(let name): return "custom:\(name)"
            }
        }
    }

    /// The value itself, in Caelyn's own vocabulary — mapping from HealthKit
    /// enums or a foreign app's spellings has already happened by this point.
    enum Value: Equatable {
        case flow(FlowLevel)
        case temperature(Double)          // °C
        case mucus(CervicalMucus)
        case ovulation(OvulationTestResult)
        case boolean(Bool)
        case symptomSeverity(Int)         // 1 mild / 2 moderate / 3 severe
        case present                      // marker types that carry no value
        case painScore(Int)               // 0-10
        case mood(Mood)
        case energy(EnergyLevel)
        case text(String)

        /// Canonical string form, stored in the ledger so a later sync can tell
        /// "unchanged since import" from "the user edited this afterwards".
        var ledgerValue: String {
            switch self {
            case .flow(let f):            return f.rawValue
            case .temperature(let t):     return String(format: "%.2f", t)
            case .mucus(let m):           return m.rawValue
            case .ovulation(let o):       return o.rawValue
            case .boolean(let b):         return b ? "1" : "0"
            case .symptomSeverity(let s): return String(s)
            case .present:                return "1"
            case .painScore(let p):       return String(p)
            case .mood(let m):            return m.rawValue
            case .energy(let e):          return e.rawValue
            case .text(let t):            return t
            }
        }
    }

    /// Start-of-day, in the calendar the reconciler was handed.
    let day: Date
    let field: Field
    let value: Value

    /// Identity of the originating record. For HealthKit this is the sample UUID;
    /// for a file it is derived deterministically from source, day and field (see
    /// `ImportRecordID`), so the same row seen twice is recognised as the same
    /// record rather than imported again.
    let recordID: UUID

    /// Bundle identifier of the app that wrote the record. Caelyn's own bundle ID
    /// here is what makes loop detection exact rather than heuristic.
    let sourceBundleID: String

    /// Human-readable origin, shown to the user ("Clue", "Apple Watch").
    let sourceName: String

    /// When the source recorded it — used only to break ties between two
    /// competing imported values for the same field. Never compared against
    /// user-entered data, which always wins regardless of age.
    let recordedAt: Date
}
