import Foundation

/// One value, for one calendar day, for one Caelyn field, traced back to the
/// exact record it came from.
///
/// This is the *only* currency the merge engine speaks. Apple Health samples and
/// rows from another app's export file both normalize into `HealthObservation`,
/// so there is a single reconciliation policy to reason about and to test —
/// rather than one merge path per source that each drift on their own.
struct HealthObservation: Equatable {

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
            }
        }
    }

    /// Start-of-day, in the calendar the reconciler was handed.
    let day: Date
    let field: Field
    let value: Value

    /// Identity of the originating record. For HealthKit this is the sample UUID;
    /// for a file import it is a hash of the source row (see `ImportSource`), so
    /// re-importing the same file twice is recognised rather than duplicated.
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
