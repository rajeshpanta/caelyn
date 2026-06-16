import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome          = 0
    case featureHighlights = 1
    case privacy          = 2
    case lastPeriod       = 3
    case cycleLength      = 4
    case periodLength     = 5
    case goals            = 6
    case reminders        = 7
    case lock             = 8
    case done             = 9

    var id: Int { rawValue }

    var showsProgressBar: Bool {
        switch self {
        case .welcome, .featureHighlights, .done: return false
        default: return true
        }
    }

    var surveyPosition: Int? {
        switch self {
        case .welcome, .featureHighlights, .done: return nil
        case .privacy:       return 1
        case .lastPeriod:    return 2
        case .cycleLength:   return 3
        case .periodLength:  return 4
        case .goals:         return 5
        case .reminders:     return 6
        case .lock:          return 7
        }
    }

    var surveyTotal: Int { 7 }
}

enum NavigationDirection {
    case forward
    case backward
}
