import Foundation

enum FlowLevel: String, Codable, CaseIterable, Identifiable {
    case spotting, light, medium, heavy
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .spotting: return "Spotting"
        case .light:    return "Light"
        case .medium:   return "Medium"
        case .heavy:    return "Heavy"
        }
    }
}

enum Symptom: String, Codable, CaseIterable, Identifiable {
    case cramps, bloating, acne, cravings, fatigue, nausea, dizziness
    case sleepChanges, tenderBreasts, headache, backPain
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cramps:        return "Cramps"
        case .bloating:      return "Bloating"
        case .acne:          return "Acne"
        case .cravings:      return "Cravings"
        case .fatigue:       return "Fatigue"
        case .nausea:        return "Nausea"
        case .dizziness:     return "Dizziness"
        case .sleepChanges:  return "Sleep changes"
        case .tenderBreasts: return "Tender breasts"
        case .headache:      return "Headache"
        case .backPain:      return "Back pain"
        }
    }
    var icon: String {
        switch self {
        case .cramps:        return "bolt.heart"
        case .bloating:      return "circle.dotted"
        case .acne:          return "drop"
        case .cravings:      return "fork.knife"
        case .fatigue:       return "moon.zzz"
        case .nausea:        return "wind"
        case .dizziness:     return "tornado"
        case .sleepChanges:  return "bed.double"
        case .tenderBreasts: return "heart.text.square"
        case .headache:      return "brain.head.profile"
        case .backPain:      return "figure.stand"
        }
    }
}

enum Mood: String, Codable, CaseIterable, Identifiable {
    case calm, happy, energetic, focused
    case sensitive, sad, anxious, irritable
    case tired, moody, lowEnergy
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .calm:      return "Calm"
        case .happy:     return "Happy"
        case .energetic: return "Energetic"
        case .focused:   return "Focused"
        case .sensitive: return "Sensitive"
        case .sad:       return "Sad"
        case .anxious:   return "Anxious"
        case .irritable: return "Irritable"
        case .tired:     return "Tired"
        case .moody:     return "Moody"
        case .lowEnergy: return "Low energy"
        }
    }
}

enum PainType: String, Codable, CaseIterable, Identifiable {
    case cramps, backPain, headache, breastTenderness, pelvicPain
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cramps:           return "Cramps"
        case .backPain:         return "Back pain"
        case .headache:         return "Headache"
        case .breastTenderness: return "Breast tenderness"
        case .pelvicPain:       return "Pelvic pain"
        }
    }
}

enum CervicalMucus: String, Codable, CaseIterable, Identifiable {
    case dry, sticky, creamy, watery, eggWhite
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .dry:      return "Dry"
        case .sticky:   return "Sticky"
        case .creamy:   return "Creamy"
        case .watery:   return "Watery"
        case .eggWhite: return "Egg white"
        }
    }
}

enum TrackingGoal: String, Codable, CaseIterable, Identifiable {
    case period, symptoms, mood, pms, ovulation, fertileWindow, reminders, doctorNotes
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .period:         return "Period"
        case .symptoms:       return "Symptoms"
        case .mood:           return "Mood"
        case .pms:            return "PMS"
        case .ovulation:      return "Ovulation"
        case .fertileWindow:  return "Fertile window"
        case .reminders:      return "Reminders"
        case .doctorNotes:    return "Doctor notes"
        }
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}
