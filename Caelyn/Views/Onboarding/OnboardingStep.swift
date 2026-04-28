import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case privacy
    case lastPeriod
    case cycleLength
    case periodLength
    case goals
    case reminders
    case lock
    case done

    var id: Int { rawValue }

    var showsProgressBar: Bool {
        switch self {
        case .welcome, .done: return false
        default: return true
        }
    }

    var surveyPosition: Int? {
        switch self {
        case .welcome, .done: return nil
        default: return rawValue
        }
    }

    var surveyTotal: Int { 7 }
}

enum NavigationDirection {
    case forward
    case backward
}
