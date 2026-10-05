import Foundation
import SwiftData

@Model
final class CycleEntry {
    // No `.unique` and a default value: both are required for CloudKit mirroring
    // (Phase 6 opt-in sync). Uniqueness-by-day is enforced in code instead of by
    // the store: every write path fetches-or-creates by day, and
    // `CycleStore.dedupeSameDay` runs at launch to merge any same-day duplicates
    // that a migration or sync race could introduce.
    var date: Date = Date()

    /// Which calendar day this entry *is*, as `yyyyMMdd`, written in the calendar
    /// she was living in at the time and never recomputed.
    ///
    /// `date` above is still the instant and still means exactly what it always
    /// meant — formatters, exports, charts and Apple Health all keep reading it.
    /// This is the identity: two entries are the same day when their keys match,
    /// which stays true after she flies somewhere. See `CivilDay`.
    ///
    /// Defaulted to 0 so the schema change is a lightweight migration (SwiftData
    /// requires a default or an optional for CloudKit mirroring either way).
    /// A 0 means "written before this property existed"; `CycleStore.dedupeSameDay`
    /// backfills those at launch.
    var dayKey: Int = 0

    /// Local midnight on the day this entry belongs to.
    ///
    /// Prefer this over `Calendar.current.startOfDay(for: entry.date)` everywhere —
    /// it is the same type in the same space, but it comes from the stored key
    /// rather than from re-truncating an instant, so it cannot drift when she
    /// travels.
    var day: Date { day(in: .current) }

    /// As `day`, in a given calendar's time zone — for an import running in her
    /// travel zone, a background health sync, or a test pinning one.
    ///
    /// Falls back to truncating the instant when the key names no day: a row
    /// written before `dayKey` existed and not yet backfilled, or one keyed by the
    /// first version of `CivilDay`, which took the device's calendar system and so
    /// wrote year 2569 on a Thai phone. That fallback is exactly what every reader
    /// computed before `dayKey` existed, so such a row reads as it always has
    /// rather than as the year 1 — which is a real `Date` that passes every
    /// reader's filters, and anchored the whole prediction to it.
    func day(in calendar: Calendar) -> Date {
        CivilDay.localDate(for: dayKey, calendar: calendar)
            ?? CivilDay.gregorian(calendar).startOfDay(for: date)
    }

    var flow: FlowLevel?
    var pain: Int?
    var painTypes: [PainType] = []
    var symptoms: [Symptom] = []
    var mood: Mood?
    var energyLevel: EnergyLevel?
    /// Severity per logged symptom: key = Symptom.rawValue, value = 1 (mild) / 2 (moderate) / 3 (severe).
    /// Only symptoms in `symptoms` array should have entries here.
    var symptomSeverity: [String: Int] = [:]
    var loggedCustomSymptoms: [String] = []
    var note: String?

    var medication: String?
    var ovulationTestResult: OvulationTestResult?
    var pregnancyTest: Bool?
    var cervicalMucus: CervicalMucus?
    var basalTemperature: Double?
    var sexualActivity: Bool?

    // Note-to-self reminder (optional; attaches to this day's note).
    // rule: nil / "date" / "beforePeriod" / "atPeriod". `noteReminderAt` is the
    // resolved fire time (chosen for .date, recomputed for cycle-relative rules).
    var noteReminderRule: String?
    var noteReminderAt: Date?
    var noteReminderDone: Bool = false

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        date: Date,
        flow: FlowLevel? = nil,
        pain: Int? = nil,
        painTypes: [PainType] = [],
        symptoms: [Symptom] = [],
        mood: Mood? = nil,
        note: String? = nil
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.dayKey = CivilDay.key(for: date)
        self.flow = flow
        self.pain = pain
        self.painTypes = painTypes
        self.symptoms = symptoms
        self.mood = mood
        self.energyLevel = nil
        self.symptomSeverity = [:]
        self.loggedCustomSymptoms = []
        self.note = note
        self.medication = nil
        self.ovulationTestResult = nil
        self.pregnancyTest = nil
        self.cervicalMucus = nil
        self.basalTemperature = nil
        self.sexualActivity = nil
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    var hasContent: Bool {
        flow != nil
            || pain != nil
            || !painTypes.isEmpty
            || !symptoms.isEmpty
            || mood != nil
            || energyLevel != nil
            || !loggedCustomSymptoms.isEmpty
            || (note?.isEmpty == false)
            || medication != nil
            || ovulationTestResult != nil
            || pregnancyTest != nil
            || cervicalMucus != nil
            || basalTemperature != nil
            || sexualActivity != nil
    }
}
