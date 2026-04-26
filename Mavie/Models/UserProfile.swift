import Foundation
import SwiftData

@Model
final class UserProfile {
    var averageCycleLength: Int
    var averagePeriodLength: Int
    var trackingGoals: [TrackingGoal]

    var lockEnabled: Bool
    var hidePreview: Bool
    var privateNotifications: Bool
    var healthKitConnected: Bool

    var firstDayOfWeek: Int
    var theme: AppTheme

    var hasOnboarded: Bool
    var lastPeriodStart: Date?

    var remindPeriodStart: Bool
    var remindDailyCheckIn: Bool
    var remindMedication: Bool
    var remindOvulation: Bool

    var isPro: Bool
    var createdAt: Date

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
        remindPeriodStart: Bool = true,
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
        self.createdAt = Date()
    }
}
