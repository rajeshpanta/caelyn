import UIKit
import UserNotifications

/// Registered via @UIApplicationDelegateAdaptor in CaelynApp.
/// Its single job is to set the UNUserNotificationCenterDelegate at the
/// earliest possible moment so we can:
///   1. Show notifications even when Caelyn is foregrounded.
///   2. Capture taps and route them to the right Home card via NotificationRouter.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Called when the app is foregrounded and a notification fires. We still
    /// show it as a banner so the user can act on it without leaving the
    /// current screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// Called when the user taps a notification (from lock screen, banner, or
    /// Notification Center). We extract the Caelyn category from the request
    /// identifier and hand it off to the in-app router.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        if let category = NotificationService.category(from: identifier) {
            Task { @MainActor in
                NotificationRouter.shared.receive(category)
            }
        }
        completionHandler()
    }
}
