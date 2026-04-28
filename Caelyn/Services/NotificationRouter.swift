import Foundation
import Observation

/// In-memory routing state for "user tapped a Caelyn notification."
/// The AppDelegate sets `pendingCategory` from
/// `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:)`,
/// and views that care (MainTabView, Home cards) observe it.
///
/// Lives in memory only — never persisted, no PII, just a routing breadcrumb.
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// Set when a notification was tapped; consumed by MainTabView, which
    /// routes the tab and re-broadcasts via the highlightedCategory environment
    /// to the relevant card.
    var pendingCategory: NotificationService.Category?

    /// Set briefly (~2s) after a tap so the relevant card can pulse.
    /// Cleared by a Task scheduled in MainTabView.
    var highlightedCategory: NotificationService.Category?

    private init() {}

    /// Called by AppDelegate on notification tap.
    func receive(_ category: NotificationService.Category) {
        pendingCategory = category
    }

    func consumePending() -> NotificationService.Category? {
        let value = pendingCategory
        pendingCategory = nil
        return value
    }
}
