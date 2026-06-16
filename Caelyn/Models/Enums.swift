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
    // Perimenopause-specific
    case hotFlash, nightSweats, brainFog, vaginalDryness, jointPain
    // Endo / PCOS-specific
    case pelvicPressure, painfulSex, hairLoss, irregularBleed, weightChanges
    // Pregnancy-specific
    case morningNausea, heartburn, swelling, shortBreath, backPainPreg
    // Postpartum-specific
    case breastEngorgement, postpartumFatigue, moodLow
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cramps:          return "Cramps"
        case .bloating:        return "Bloating"
        case .acne:            return "Acne"
        case .cravings:        return "Cravings"
        case .fatigue:         return "Fatigue"
        case .nausea:          return "Nausea"
        case .dizziness:       return "Dizziness"
        case .sleepChanges:    return "Sleep changes"
        case .tenderBreasts:   return "Tender breasts"
        case .headache:        return "Headache"
        case .backPain:        return "Back pain"
        case .hotFlash:        return "Hot flash"
        case .nightSweats:     return "Night sweats"
        case .brainFog:        return "Brain fog"
        case .vaginalDryness:  return "Vaginal dryness"
        case .jointPain:       return "Joint pain"
        case .pelvicPressure:   return "Pelvic pressure"
        case .painfulSex:       return "Painful sex"
        case .hairLoss:         return "Hair loss"
        case .irregularBleed:   return "Irregular bleeding"
        case .weightChanges:    return "Weight changes"
        case .morningNausea:    return "Morning nausea"
        case .heartburn:        return "Heartburn"
        case .swelling:         return "Swelling"
        case .shortBreath:      return "Shortness of breath"
        case .backPainPreg:     return "Back pain"
        case .breastEngorgement:return "Breast engorgement"
        case .postpartumFatigue:return "Postpartum fatigue"
        case .moodLow:          return "Low mood"
        }
    }
    var icon: String {
        switch self {
        case .cramps:          return "bolt.heart"
        case .bloating:        return "circle.dotted"
        case .acne:            return "drop"
        case .cravings:        return "fork.knife"
        case .fatigue:         return "moon.zzz"
        case .nausea:          return "wind"
        case .dizziness:       return "tornado"
        case .sleepChanges:    return "bed.double"
        case .tenderBreasts:   return "heart.text.square"
        case .headache:        return "brain.head.profile"
        case .backPain:        return "figure.stand"
        case .hotFlash:        return "thermometer.sun"
        case .nightSweats:     return "cloud.rain"
        case .brainFog:        return "brain"
        case .vaginalDryness:  return "drop.degreesign"
        case .jointPain:       return "figure.walk"
        case .pelvicPressure:    return "waveform.path.ecg"
        case .painfulSex:        return "heart.slash"
        case .hairLoss:          return "scissors"
        case .irregularBleed:    return "drop.triangle"
        case .weightChanges:     return "scalemass"
        case .morningNausea:     return "face.smiling"
        case .heartburn:         return "flame"
        case .swelling:          return "drop.fill"
        case .shortBreath:       return "wind"
        case .backPainPreg:      return "figure.stand"
        case .breastEngorgement: return "heart.text.square"
        case .postpartumFatigue: return "moon.zzz"
        case .moodLow:           return "cloud.rain"
        }
    }
    static var pregnancySymptoms: [Symptom] {
        [.morningNausea, .heartburn, .swelling, .shortBreath, .backPainPreg, .fatigue, .nausea]
    }
    static var postpartumSymptoms: [Symptom] {
        [.breastEngorgement, .postpartumFatigue, .moodLow, .sleepChanges, .fatigue]
    }
    static var perimenoSymptoms: [Symptom] {
        [.hotFlash, .nightSweats, .brainFog, .vaginalDryness, .jointPain, .sleepChanges, .fatigue]
    }
    static var endoSymptoms: [Symptom] {
        [.cramps, .bloating, .backPain, .fatigue, .nausea, .pelvicPressure, .painfulSex]
    }
    static var pcosSymptoms: [Symptom] {
        [.acne, .fatigue, .bloating, .hairLoss, .irregularBleed, .weightChanges, .brainFog]
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

enum EnergyLevel: String, Codable, CaseIterable, Identifiable {
    case drained, low, moderate, high, energized
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .drained:   return "Drained"
        case .low:       return "Low"
        case .moderate:  return "Moderate"
        case .high:      return "High"
        case .energized: return "Energized"
        }
    }
    var icon: String {
        switch self {
        case .drained:   return "zzz"
        case .low:       return "tortoise.fill"
        case .moderate:  return "minus.circle.fill"
        case .high:      return "hare.fill"
        case .energized: return "bolt.fill"
        }
    }
}

enum BirthControlMethod: String, Codable, CaseIterable, Identifiable {
    case pill, patch, ring
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .pill:  return "Pill"
        case .patch: return "Patch"
        case .ring:  return "Ring"
        }
    }
    var icon: String {
        switch self {
        case .pill:  return "pills.fill"
        case .patch: return "bandage.fill"
        case .ring:  return "circle.fill"
        }
    }
    var reminderBody: String {
        switch self {
        case .pill:  return "Time to take your pill."
        case .patch: return "Time to change your patch."
        case .ring:  return "Ring reminder — check your schedule."
        }
    }
}

enum OvulationTestResult: String, Codable, CaseIterable, Identifiable {
    case negative, lhSurge, positive
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .negative: return "Negative"
        case .lhSurge:  return "LH Surge"
        case .positive: return "Positive"
        }
    }
    var icon: String {
        switch self {
        case .negative: return "minus.circle"
        case .lhSurge:  return "waveform.path.ecg"
        case .positive: return "checkmark.circle.fill"
        }
    }
    var color: String {
        switch self {
        case .negative: return "deepPlumText"
        case .lhSurge:  return "warmSand"
        case .positive: return "successSage"
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
