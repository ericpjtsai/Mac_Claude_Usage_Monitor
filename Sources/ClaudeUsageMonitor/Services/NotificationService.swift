import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, @unchecked Sendable {
    static let shared = NotificationService()

    var onAuthNotificationTapped: (() -> Void)?

    /// Whether UNUserNotificationCenter is available (requires a proper app bundle)
    private var isAvailable = false

    private override init() {
        super.init()
        // UNUserNotificationCenter crashes without a bundle, so guard against it
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("[Notification] No bundle identifier — notifications disabled (running outside .app bundle?)")
            return
        }
        isAvailable = true
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("[Notification] Permission error: \(error.localizedDescription)")
            } else {
                NSLog("[Notification] Permission granted: \(granted)")
            }
        }
    }

    func sendAuthExpiredNotification() {
        guard isAvailable else {
            NSLog("[Notification] Notifications unavailable, showing auth window instead")
            Task { @MainActor in
                self.onAuthNotificationTapped?()
            }
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Session Expired"
        content.body = "Your Claude credentials have expired. Click to sign in again."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "auth-expired", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("[Notification] Failed to send: \(error.localizedDescription)")
            }
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == "auth-expired" {
            Task { @MainActor in
                self.onAuthNotificationTapped?()
            }
        }
        completionHandler()
    }

    // Show notification even when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
