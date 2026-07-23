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
