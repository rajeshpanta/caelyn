import Foundation
import SwiftData

@Model
final class CycleEntry {
    @Attribute(.unique) var date: Date
    var flow: FlowLevel?
    var pain: Int?
    var painTypes: [PainType]
    var symptoms: [Symptom]
    var mood: Mood?
    var note: String?

    var medication: String?
    var ovulationTest: Bool?
    var pregnancyTest: Bool?
    var cervicalMucus: CervicalMucus?
    var basalTemperature: Double?
    var sexualActivity: Bool?

    var createdAt: Date
    var updatedAt: Date

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
        self.note = note
        self.medication = nil
        self.ovulationTest = nil
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
            || (note?.isEmpty == false)
            || medication != nil
            || ovulationTest != nil
            || pregnancyTest != nil
            || cervicalMucus != nil
            || basalTemperature != nil
            || sexualActivity != nil
    }
}
