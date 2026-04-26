import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class OnboardingViewModel {
    var step: OnboardingStep = .welcome
    var navigationDirection: NavigationDirection = .forward

    var lastPeriodStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    var notSureLastPeriod: Bool = false

    var cycleLength: Int = 28
    var notSureCycleLength: Bool = false

    var periodLength: Int = 5
    var notSurePeriodLength: Bool = false

    var trackingGoals: Set<TrackingGoal> = [.period, .symptoms, .mood, .pms]

    var remindPeriodStart: Bool = true
    var remindDailyCheckIn: Bool = false
    var remindMedication: Bool = false
    var remindOvulation: Bool = false
    var noReminders: Bool = false

    var enableLock: Bool = false

    func next() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        navigationDirection = .forward
        step = next
    }

    func back() {
        guard let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        navigationDirection = .backward
        step = prev
    }

    func toggleGoal(_ goal: TrackingGoal) {
        if trackingGoals.contains(goal) {
            trackingGoals.remove(goal)
        } else {
            trackingGoals.insert(goal)
        }
    }

    func setNoReminders(_ noneSelected: Bool) {
        noReminders = noneSelected
        if noneSelected {
            remindPeriodStart = false
            remindDailyCheckIn = false
            remindMedication = false
            remindOvulation = false
        }
    }

    func updateReminder(period: Bool? = nil, daily: Bool? = nil, medication: Bool? = nil, ovulation: Bool? = nil) {
        if let period { remindPeriodStart = period }
        if let daily { remindDailyCheckIn = daily }
        if let medication { remindMedication = medication }
        if let ovulation { remindOvulation = ovulation }
        if remindPeriodStart || remindDailyCheckIn || remindMedication || remindOvulation {
            noReminders = false
        }
    }

    func complete(in modelContext: ModelContext) {
        let profile = UserProfile(
            averageCycleLength: cycleLength,
            averagePeriodLength: periodLength,
            trackingGoals: Array(trackingGoals),
            lockEnabled: enableLock,
            hidePreview: false,
            privateNotifications: true,
            healthKitConnected: false,
            firstDayOfWeek: Calendar.current.firstWeekday,
            theme: .system,
            hasOnboarded: true,
            lastPeriodStart: notSureLastPeriod ? nil : lastPeriodStart,
            remindPeriodStart: remindPeriodStart,
            remindDailyCheckIn: remindDailyCheckIn,
            remindMedication: remindMedication,
            remindOvulation: remindOvulation,
            isPro: false
        )
        modelContext.insert(profile)
        try? modelContext.save()
    }
}
