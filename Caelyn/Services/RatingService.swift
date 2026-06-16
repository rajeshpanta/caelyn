import StoreKit
import SwiftUI

/// Manages when and how the native App Store review prompt is shown.
///
/// Strategy:
/// - Prompt after the user has logged 5 entries (meaningful engagement)
/// - Never prompt more than once per 30 days
/// - Never prompt on first launch day
/// - Back off if the user has already been asked 3 times
enum RatingService {

    private enum Keys {
        static let sessionCount        = "caelyn.rating.sessionCount"
        static let lastPromptDate      = "caelyn.rating.lastPromptDate"
        static let timesPrompted       = "caelyn.rating.timesPrompted"
        static let firstLaunchDate     = "caelyn.rating.firstLaunchDate"
    }

    private static let minDaysBetweenPrompts: Int = 30
    private static let maxPromptsLifetime: Int     = 3
    private static let minDaysSinceInstall: Int    = 2

    // MARK: - Public API

    /// Call this after a meaningful user action (e.g. saving a log entry).
    /// Internally decides whether the timing is right to show the prompt.
    @MainActor
    static func considerRequestingReview(loggedEntryCount: Int) {
        recordFirstLaunchIfNeeded()
        guard shouldPrompt(entryCount: loggedEntryCount) else { return }
        requestReview()
    }

    // MARK: - Internal logic

    private static func shouldPrompt(entryCount: Int) -> Bool {
        let defaults = UserDefaults.standard

        // Need at least 5 logged entries for genuine engagement
        guard entryCount >= 5 else { return false }

        // Don't ask more than maxPromptsLifetime times ever
        let timesPrompted = defaults.integer(forKey: Keys.timesPrompted)
        guard timesPrompted < maxPromptsLifetime else { return false }

        // Wait at least minDaysSinceInstall days after install
        if let firstLaunch = defaults.object(forKey: Keys.firstLaunchDate) as? Date {
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: firstLaunch, to: .now).day ?? 0
            guard daysSinceInstall >= minDaysSinceInstall else { return false }
        }

        // Respect the cool-down between prompts
        if let lastDate = defaults.object(forKey: Keys.lastPromptDate) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: .now).day ?? 0
            guard daysSince >= minDaysBetweenPrompts else { return false }
        }

        return true
    }

    @MainActor
    private static func requestReview() {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: Keys.lastPromptDate)
        defaults.set(defaults.integer(forKey: Keys.timesPrompted) + 1, forKey: Keys.timesPrompted)

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private static func recordFirstLaunchIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.firstLaunchDate) == nil {
            defaults.set(Date(), forKey: Keys.firstLaunchDate)
        }
    }
}
