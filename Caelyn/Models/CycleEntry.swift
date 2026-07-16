import Foundation
import SwiftData

@Model
final class CycleEntry {
    // No `.unique` and a default value: both are required for CloudKit mirroring
    // (Phase 6 opt-in sync). Uniqueness-by-day is enforced in code (log flow
    // fetches-or-creates by date) rather than by the store, and a cross-device
    // dedup pass guards against sync races.
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
