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

    var remindPeriodStart: Bool = false
    var remindDailyCheckIn: Bool = false
    var remindMedication: Bool = false
    var remindOvulation: Bool = false
    var noReminders: Bool = false

    var enableLock: Bool = false
    var healthKitConnected: Bool = false

    // Switch Kit: history imported from Apple Health during onboarding, so a
    // switcher's first prediction is grounded in their real past cycles.
    var healthImportedEntries: Int = 0
    var healthImportedCycles: Int = 0
    var importedLastPeriodStart: Date?

    func skipHealthStep() {
        // Skip the health step if HealthKit isn't available on this device
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        navigationDirection = .forward
        step = next
        Haptics.selection()
    }

    func next() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        navigationDirection = .forward
        step = next
        Haptics.selection()
    }

    func back() {
        guard let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        navigationDirection = .backward
        step = prev
        Haptics.selection()
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
        // A profile can already exist here for one reason: iCloud delivered hers
        // from another device while she was still answering. This used to return
        // straight away, which dropped every answer she had just given AND left
        // `hasOnboarded` false on the row that survived — so onboarding reappeared
        // on the next launch, and again on the one after that.
        //
        // Her existing profile wins, because it carries settings, reminders and a
        // name she has already chosen. It is adopted rather than replaced: marked
        // onboarded so she gets into the app, and filled in only where it has
        // nothing of its own to say.
        if let existing = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?
            .sorted(by: { $0.createdAt < $1.createdAt }).first {
            adopt(existing)
            modelContext.saveOrLog()
            return
        }
        let profile = UserProfile(
            averageCycleLength: notSureCycleLength ? 28 : cycleLength,
            averagePeriodLength: notSurePeriodLength ? 5 : periodLength,
            trackingGoals: Array(trackingGoals),
            lockEnabled: enableLock,
            hidePreview: false,
            privateNotifications: true,
            healthKitConnected: healthKitConnected,
            firstDayOfWeek: Calendar.current.firstWeekday,
            theme: .system,
            hasOnboarded: true,
            // If the user was unsure of their last period but we imported their
            // Apple Health history, anchor predictions to the imported data.
            lastPeriodStart: notSureLastPeriod ? importedLastPeriodStart : lastPeriodStart,
            remindPeriodStart: remindPeriodStart,
            remindDailyCheckIn: remindDailyCheckIn,
            remindMedication: remindMedication,
            remindOvulation: remindOvulation,
            isPro: false
        )
        if healthKitConnected {
            // Onboarding asks for READ only. Writing is granted later, from
            // Settings, so flagging writes on here would make them fail silently.
            profile.hkReadFlow = true
            profile.hkReadSymptoms = true
            profile.hkReadFertility = true
        }
        modelContext.insert(profile)
        modelContext.saveOrLog()
    }

    /// Bring a profile that already exists into the app, without overwriting
    /// anything it already knows.
    private func adopt(_ profile: UserProfile) {
        profile.hasOnboarded = true

        // Only answer what it has not answered. A synced profile's own cycle
        // settings are hers too, and more considered than a first-run guess.
        if profile.lastPeriodStart == nil {
            profile.lastPeriodStart = notSureLastPeriod ? importedLastPeriodStart : lastPeriodStart
        }
        if profile.trackingGoals.isEmpty {
            profile.trackingGoals = Array(trackingGoals)
        }
        if healthKitConnected, !profile.healthKitConnected {
            profile.healthKitConnected = true
            profile.hkReadFlow = true
            profile.hkReadSymptoms = true
            profile.hkReadFertility = true
        }
        if enableLock { profile.lockEnabled = true }
    }
}
