import Foundation
import SwiftData

@Model
final class UserProfile {
    var averageCycleLength: Int = 28
    var averagePeriodLength: Int = 5
    var trackingGoals: [TrackingGoal] = []

    var lockEnabled: Bool = false
    var hidePreview: Bool = false
    var privateNotifications: Bool = true
    var healthKitConnected: Bool = false

    var hkReadFlow: Bool = false
    var hkWriteFlow: Bool = false
    var hkReadSymptoms: Bool = false
    var hkWriteSymptoms: Bool = false

    var firstDayOfWeek: Int = 1
    var theme: AppTheme = .system

    var hasOnboarded: Bool = false
    var lastPeriodStart: Date?

    var remindPeriodStart: Bool = false
    var remindDailyCheckIn: Bool = false
    var remindMedication: Bool = false
    var remindOvulation: Bool = false

    /// User-defined symptom names, max 5.
    var customSymptoms: [String] = []
    /// True when the user has explicitly opted into Irregular Cycle Mode.
    var irregularModeEnabled: Bool = false
    /// True when the user dismissed the auto-detection banner without enabling the mode.
    var irregularModeDismissed: Bool = false

    var dailyCheckInHour: Int = 20
    var dailyCheckInMinute: Int = 0
    var medicationHour: Int = 9
    var medicationMinute: Int = 0
    var periodReminderHour: Int = 9
    var periodReminderMinute: Int = 0
    var periodReminderDaysBefore: Int = 2
    var ovulationReminderHour: Int = 9
    var ovulationReminderMinute: Int = 0

    // Condition Modes
    var perimenoEnabled: Bool = false
    var endoEnabled: Bool = false
    var pcosEnabled: Bool = false
    var ttcEnabled: Bool = false
    // Pregnancy Mode
    var pregnancyEnabled: Bool = false
    var pregnancyDueDate: Date?
    // Postpartum Mode
    var postpartumEnabled: Bool = false
    var postpartumBirthDate: Date?

    // Birth Control Mode
    var birthControlEnabled: Bool = false
    var birthControlMethod: BirthControlMethod = .pill
    var birthControlReminderEnabled: Bool = false
    var birthControlReminderHour: Int = 8
    var birthControlReminderMinute: Int = 0
    var birthControlStartDate: Date?

    var isPro: Bool = false
    var createdAt: Date = Date()

    init(
        averageCycleLength: Int = 28,
        averagePeriodLength: Int = 5,
        trackingGoals: [TrackingGoal] = [],
        lockEnabled: Bool = false,
        hidePreview: Bool = false,
        privateNotifications: Bool = true,
        healthKitConnected: Bool = false,
        firstDayOfWeek: Int = 1,
        theme: AppTheme = .system,
        hasOnboarded: Bool = false,
        lastPeriodStart: Date? = nil,
        remindPeriodStart: Bool = false,
        remindDailyCheckIn: Bool = false,
        remindMedication: Bool = false,
        remindOvulation: Bool = false,
        isPro: Bool = false
    ) {
        self.averageCycleLength = averageCycleLength
        self.averagePeriodLength = averagePeriodLength
        self.trackingGoals = trackingGoals
        self.lockEnabled = lockEnabled
        self.hidePreview = hidePreview
        self.privateNotifications = privateNotifications
        self.healthKitConnected = healthKitConnected
        self.firstDayOfWeek = firstDayOfWeek
        self.theme = theme
        self.hasOnboarded = hasOnboarded
        self.lastPeriodStart = lastPeriodStart
        self.remindPeriodStart = remindPeriodStart
        self.remindDailyCheckIn = remindDailyCheckIn
        self.remindMedication = remindMedication
        self.remindOvulation = remindOvulation
        self.isPro = isPro
        self.customSymptoms = []
        self.birthControlMethod = .pill
        self.birthControlStartDate = nil
        self.createdAt = Date()
    }
}
