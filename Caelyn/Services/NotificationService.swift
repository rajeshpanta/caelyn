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

    /// All notification categories Caelyn has ever scheduled. We keep
    /// .periodUpcoming and .ovulation in the enum (rather than removing them)
    /// for two reasons:
    ///   1. cancelAll() needs to find and remove any legacy pending requests
    ///      from earlier app versions that used to schedule them.
    ///   2. The smart-tap router knows the rawValue prefix even if we never
    ///      schedule new ones.
    /// Caelyn's "private envelopes" architecture intentionally keeps cycle and
    /// ovulation events as in-app cards (HomeHeroCard / activePeriodPrompt /
    /// latePeriodPrompt) rather than OS notifications — they never travel to
    /// the lock screen, Notification Center, Apple Watch, or notification logs.
    enum Category: String, CaseIterable {
        case periodUpcoming = "caelyn.period.upcoming"
        case dailyCheckIn   = "caelyn.daily.checkin"
        case medication     = "caelyn.medication"
        case ovulation      = "caelyn.ovulation"
    }

    /// Identifier prefixes used by earlier builds (pre-rebrand). Kept so
    /// `cancelAll()` can purge any pending requests still queued on TestFlight
    /// devices that installed the app under the old branding.
    /// Declared `nonisolated` because cancelAll() reads it from the
    /// `getPendingNotificationRequests` completion handler, which is not
    /// actor-isolated.
    nonisolated private static let legacyCategoryPrefixes: [String] = [
        "mavie.period.upcoming",
        "mavie.daily.checkin",
        "mavie.medication",
        "mavie.ovulation"
    ]

    /// How many future days of one-shot reminders to pre-schedule. Picking 7
    /// means the user keeps getting reminded for a week even if they never
    /// open the app — but the next sync (e.g. after they open it once) refreshes
    /// the schedule. iOS allows up to 64 pending requests; at 7 days × 2
    /// categories = 14 we have plenty of headroom.
    private static let scheduleHorizonDays = 7

    /// Quiet hours during which Caelyn will not fire any notification. Notifications
    /// scheduled for these hours get pushed forward to `quietHoursEnd`.
    private static let quietHoursStart = 22  // 22:00
    private static let quietHoursEnd   = 7   // 07:00

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
                title: isPrivate ? "Caelyn reminder" : "Your period may start soon",
                body:  isPrivate ? "Tap to check in." : "Caelyn predicts your period in a couple of days.",
                identifier: category.rawValue
            )
        case .dailyCheckIn:
            return NotificationContent(
                title: isPrivate ? "Caelyn reminder" : "Today's check-in",
                body:  isPrivate ? "Tap to log how you're feeling." : "How are you feeling today?",
                identifier: category.rawValue
            )
        case .medication:
            return NotificationContent(
                title: isPrivate ? "Caelyn reminder" : "Medication",
                body:  isPrivate ? "Tap to log." : "Time to log today's medication.",
                identifier: category.rawValue
            )
        case .ovulation:
            return NotificationContent(
                title: isPrivate ? "Caelyn reminder" : "Ovulation window",
                body:  isPrivate ? "Tap to learn more." : "Caelyn estimates ovulation is around now.",
                identifier: category.rawValue
            )
        }
    }

    /// Parse a notification request identifier back to a Category. Identifiers
    /// look like `caelyn.daily.checkin.20260426` for our per-day one-shots, or
    /// the bare `caelyn.daily.checkin` for legacy / non-dated requests.
    static func category(from identifier: String) -> Category? {
        for category in Category.allCases where identifier.hasPrefix(category.rawValue) {
            return category
        }
        return nil
    }

    // MARK: - Scheduling

    /// Cancel every pending Caelyn notification, current and legacy. Called at
    /// the start of every sync and from Settings → Delete all data.
    static func cancelAll() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let caelynIDs = requests
                .map(\.identifier)
                .filter { id in
                    Category.allCases.contains { id.hasPrefix($0.rawValue) }
                        || legacyCategoryPrefixes.contains { id.hasPrefix($0) }
                }
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: caelynIDs)
        }
    }

    /// Pre-schedule the next N days of daily check-in and medication one-shots.
    ///
    /// This replaces the old repeating-trigger model so we can suppress *today's*
    /// reminder when the user has already logged the relevant data. Period and
    /// ovulation are intentionally not scheduled — they live as in-app cards.
    static func sync(profile: UserProfile, todayEntry: CycleEntry?) async {
        cancelAll()

        guard await authorizationStatus() == .authorized else { return }

        let isPrivate = profile.privateNotifications
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        if profile.remindDailyCheckIn {
            let moodLoggedToday = todayEntry?.mood != nil
            for offset in 0..<scheduleHorizonDays {
                guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
                // Suppress today's reminder if the user already logged a mood.
                if offset == 0 && moodLoggedToday { continue }
                guard let fire = scheduledFireDate(
                    on: day,
                    hour: profile.dailyCheckInHour,
                    minute: profile.dailyCheckInMinute
                ) else { continue }
                await scheduleOneShot(
                    category: .dailyCheckIn,
                    isPrivate: isPrivate,
                    fireDate: fire,
                    interruptionLevel: .passive
                )
            }
        }

        if profile.remindMedication {
            let medLoggedToday = (todayEntry?.medication?.isEmpty == false)
            for offset in 0..<scheduleHorizonDays {
                guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
                if offset == 0 && medLoggedToday { continue }
                guard let fire = scheduledFireDate(
                    on: day,
                    hour: profile.medicationHour,
                    minute: profile.medicationMinute
                ) else { continue }
                await scheduleOneShot(
                    category: .medication,
                    isPrivate: isPrivate,
                    fireDate: fire,
                    interruptionLevel: .timeSensitive
                )
            }
        }
    }

    /// Read the live store and resync. Called on app foreground.
    static func syncFromLiveStore() async {
        let context = Persistence.live.mainContext
        guard let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first else { return }
        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let todayEntry = entries.first { cal.isDate($0.date, inSameDayAs: today) }
        await sync(profile: profile, todayEntry: todayEntry)
    }

    // MARK: - Internals (exposed `internal` for unit tests)

    /// Compute the actual fire date for a given calendar day + time, respecting
    /// quiet hours. Returns nil if the resulting date is in the past.
    static func scheduledFireDate(on day: Date, hour: Int, minute: Int, now: Date = .now) -> Date? {
        let cal = Calendar.current
        guard let initial = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return nil }
        let shifted = shiftOutOfQuietHours(initial)
        return shifted > now ? shifted : nil
    }

    /// If `date` falls in 22:00–07:00, push it to the next 07:00.
    static func shiftOutOfQuietHours(_ date: Date) -> Date {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let inEveningQuiet = hour >= quietHoursStart        // 22, 23
        let inMorningQuiet = hour < quietHoursEnd           // 0–6
        guard inEveningQuiet || inMorningQuiet else { return date }

        let dayBase = inEveningQuiet
            ? cal.date(byAdding: .day, value: 1, to: date) ?? date
            : date
        return cal.date(bySettingHour: quietHoursEnd, minute: 0, second: 0, of: dayBase) ?? date
    }

    private static func scheduleOneShot(
        category: Category,
        isPrivate: Bool,
        fireDate: Date,
        interruptionLevel: UNNotificationInterruptionLevel
    ) async {
        let content = makeContent(category: category, isPrivate: isPrivate, interruptionLevel: interruptionLevel)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = "\(category.rawValue).\(dateSuffix(for: fireDate))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func dateSuffix(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func makeContent(
        category: Category,
        isPrivate: Bool,
        interruptionLevel: UNNotificationInterruptionLevel
    ) -> UNMutableNotificationContent {
        let info = content(for: category, isPrivate: isPrivate)
        let content = UNMutableNotificationContent()
        content.title = info.title
        content.body = info.body
        // Passive notifications are silent — no sound, no banner. They just appear
        // in Notification Center for the user to find when she chooses.
        // .timeSensitive notifications break Focus modes (used for medication only).
        // .active is the default for everything else.
        if interruptionLevel != .passive {
            content.sound = .default
        }
        content.interruptionLevel = interruptionLevel
        return content
    }
}
