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
        case .menstrual:  return MavieColor.softRose
        case .follicular: return MavieColor.warmSand
        case .ovulation:  return MavieColor.successSage
        case .luteal:     return MavieColor.warmSand
        case .pms:        return MavieColor.primaryPlum
        case .unknown:    return MavieColor.primaryPlum
        }
    }

    var tintBackground: Color {
        switch self {
        case .menstrual:  return MavieColor.blush
        case .follicular: return MavieColor.warmSand.opacity(0.45)
        case .ovulation:  return MavieColor.sage
        case .luteal:     return MavieColor.warmSand.opacity(0.4)
        case .pms:        return MavieColor.lavender
        case .unknown:    return MavieColor.lavender.opacity(0.6)
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

enum Confidence: String {
    case low      // < 3 cycles logged
    case medium   // 3–5 cycles
    case high     // 6+ cycles

    var displayText: String {
        switch self {
        case .low:    return "Mavie is still learning your pattern."
        case .medium: return "Predictions are warming up."
        case .high:   return "Predictions are confident."
        }
    }
}
