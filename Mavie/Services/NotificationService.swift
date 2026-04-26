import Foundation
import UserNotifications
import SwiftData

struct NotificationContent {
    let title: String
    let body: String
    let identifier: String
}

@MainActor
enum NotificationService {

    enum Category: String, CaseIterable {
        case periodUpcoming = "mavie.period.upcoming"
        case dailyCheckIn   = "mavie.daily.checkin"
        case medication     = "mavie.medication"
        case ovulation      = "mavie.ovulation"
    }

    // MARK: - Permission

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Request permission. Safe to call repeatedly — iOS will only show the prompt once.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Content (testable)

    /// The title/body shown for a notification. Switches to neutral phrasing when
    /// privateNotifications is on so a glance at the lock screen reveals nothing.
    static func content(for category: Category, isPrivate: Bool) -> NotificationContent {
        switch category {
        case .periodUpcoming:
            return NotificationContent(
                title: isPrivate ? "Mavie reminder" : "Your period may start soon",
                body:  isPrivate ? "Tap to check in." : "Mavie predicts your period in a couple of days.",
                identifier: category.rawValue
            )
        case .dailyCheckIn:
            return NotificationContent(
                title: isPrivate ? "Mavie reminder" : "Today's check-in",
                body:  isPrivate ? "Tap to log how you're feeling." : "How are you feeling today?",
                identifier: category.rawValue
            )
        case .medication:
            return NotificationContent(
                title: isPrivate ? "Mavie reminder" : "Medication",
                body:  isPrivate ? "Tap to log." : "Time to log today's medication.",
                identifier: category.rawValue
            )
        case .ovulation:
            return NotificationContent(
                title: isPrivate ? "Mavie reminder" : "Ovulation window",
                body:  isPrivate ? "Tap to learn more." : "Mavie estimates ovulation is around now.",
                identifier: category.rawValue
            )
        }
    }

    // MARK: - Scheduling

    static func cancelAll() {
        let identifiers = Category.allCases.map(\.rawValue)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Cancel and re-schedule based on current profile + predictions. Idempotent.
    static func sync(profile: UserProfile, predictedNextPeriod: Date?, predictedOvulation: Date?) async {
        cancelAll()

        guard await authorizationStatus() == .authorized else { return }

        let isPrivate = profile.privateNotifications

        if profile.remindPeriodStart, let next = predictedNextPeriod {
            await scheduleOneShot(
                category: .periodUpcoming,
                isPrivate: isPrivate,
                fireDate: triggerDate(daysBefore: 2, from: next, hour: 10)
            )
        }
        if profile.remindDailyCheckIn {
            await scheduleDaily(
                category: .dailyCheckIn,
                isPrivate: isPrivate,
                hour: profile.dailyCheckInHour,
                minute: profile.dailyCheckInMinute
            )
        }
        if profile.remindMedication {
            await scheduleDaily(
                category: .medication,
                isPrivate: isPrivate,
                hour: profile.medicationHour,
                minute: profile.medicationMinute
            )
        }
        if profile.remindOvulation, let ovulation = predictedOvulation {
            await scheduleOneShot(
                category: .ovulation,
                isPrivate: isPrivate,
                fireDate: triggerDate(daysBefore: 1, from: ovulation, hour: 10)
            )
        }
    }

    /// Pull the live profile + entries from the persistent store and resync.
    /// Called on app foreground so predictions stay fresh as the cycle progresses.
    static func syncFromLiveStore() async {
        let context = Persistence.live.mainContext
        guard let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first else { return }
        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []

        let (next, ovulation): (Date?, Date?) = {
            guard let last = profile.lastPeriodStart else { return (nil, nil) }
            let cycles = PredictionEngine.cycles(from: entries)
            let avgLen = PredictionEngine.averageCycleLength(of: cycles, fallback: profile.averageCycleLength)
            let nextStart = PredictionEngine.nextPeriodStart(lastPeriodStart: last, cycleLength: avgLen)
            let ovulation = PredictionEngine.ovulationEstimate(nextPeriodStart: nextStart)
            return (nextStart, ovulation)
        }()

        await sync(profile: profile, predictedNextPeriod: next, predictedOvulation: ovulation)
    }

    // MARK: - Internals

    private static func triggerDate(daysBefore: Int, from anchor: Date, hour: Int) -> Date? {
        let cal = Calendar.current
        guard let day = cal.date(byAdding: .day, value: -daysBefore, to: anchor) else { return nil }
        let candidate = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        return candidate > .now ? candidate : nil
    }

    private static func scheduleOneShot(category: Category, isPrivate: Bool, fireDate: Date?) async {
        guard let fireDate else { return }
        let content = makeContent(category: category, isPrivate: isPrivate)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: category.rawValue, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func scheduleDaily(category: Category, isPrivate: Bool, hour: Int, minute: Int) async {
        let content = makeContent(category: category, isPrivate: isPrivate)
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: category.rawValue, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func makeContent(category: Category, isPrivate: Bool) -> UNMutableNotificationContent {
        let info = content(for: category, isPrivate: isPrivate)
        let content = UNMutableNotificationContent()
        content.title = info.title
        content.body = info.body
        content.sound = .default
        return content
    }
}
