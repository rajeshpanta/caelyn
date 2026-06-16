import Foundation
import SwiftUI

struct Cycle: Equatable {
    let start: Date
    let length: Int
    let periodLength: Int
}

enum CyclePhase: String, CaseIterable, Identifiable {
    case menstrual
    case follicular
    case ovulation
    case luteal
    case pms
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .menstrual:  return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulation:  return "Ovulation window"
        case .luteal:     return "Luteal"
        case .pms:        return "PMS window"
        case .unknown:    return "Cycle"
        }
    }

    var hint: String {
        switch self {
        case .menstrual:  return "Take it easy today."
        case .follicular: return "A fresh-energy phase."
        case .ovulation:  return "Estimated ovulation window."
        case .luteal:     return "Your body is settling in."
        case .pms:        return "Be gentle with yourself."
        case .unknown:    return "Log a cycle to learn your patterns."
        }
    }

    var accentColor: Color {
        switch self {
        case .menstrual:  return CaelynColor.softRose
        case .follicular: return CaelynColor.warmSand
        case .ovulation:  return CaelynColor.successSage
        case .luteal:     return CaelynColor.warmSand
        case .pms:        return CaelynColor.primaryPlum
        case .unknown:    return CaelynColor.primaryPlum
        }
    }

    var tintBackground: Color {
        switch self {
        case .menstrual:  return CaelynColor.blush
        case .follicular: return CaelynColor.warmSand.opacity(0.45)
        case .ovulation:  return CaelynColor.sage
        case .luteal:     return CaelynColor.warmSand.opacity(0.4)
        case .pms:        return CaelynColor.lavender
        case .unknown:    return CaelynColor.lavender.opacity(0.6)
        }
    }

    var icon: String {
        switch self {
        case .menstrual:  return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulation:  return "sun.max.fill"
        case .luteal:     return "moon.fill"
        case .pms:        return "cloud.fill"
        case .unknown:    return "circle.dotted"
        }
    }
}

// MARK: - Irregular Cycle

enum IrregularCycleReason: String {
    case highVariation   = "High cycle-length variation"
    case longCycles      = "Consistently long cycles"
    case shortCycles     = "Consistently short cycles"
    case skippedPeriods  = "Infrequent periods (gaps > 45 days)"
    case increasingShift = "Cycles becoming noticeably longer or shorter"

    var note: String {
        switch self {
        case .highVariation:
            return "Your cycle length varies significantly between months, which can make predictions less accurate. This is common and may indicate hormonal fluctuation."
        case .longCycles:
            return "Your cycles are consistently longer than 35 days. This is sometimes associated with conditions like PCOS. It's worth discussing with your doctor."
        case .shortCycles:
            return "Your cycles are consistently shorter than 21 days. A healthcare provider can help determine if this is within normal range for you."
        case .skippedPeriods:
            return "Caelyn has detected gaps of 45 days or more, suggesting some periods may have been missed or skipped."
        case .increasingShift:
            return "Your cycles have been progressively shifting in length. This can be a normal change or an early sign of hormonal shifts — worth tracking closely."
        }
    }
}

enum IrregularCycleStatus: Equatable {
    case regular
    case irregular(reason: IrregularCycleReason)
    case insufficient  // fewer than 3 completed cycles
}

enum Confidence: String {
    case low      // < 3 cycles logged
    case medium   // 3–5 cycles
    case high     // 6+ cycles

    var displayText: String {
        switch self {
        case .low:    return "Caelyn is still learning your pattern."
        case .medium: return "Predictions are warming up."
        case .high:   return "Predictions are confident."
        }
    }
}
