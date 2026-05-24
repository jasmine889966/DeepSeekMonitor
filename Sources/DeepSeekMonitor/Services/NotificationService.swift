import Foundation
import UserNotifications

protocol UserNotifying: Sendable {
    func requestAuthorization() async
    func notify(title: String, body: String) async
}

struct NotificationService: UserNotifying {
    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            // Authorization failure should not block data monitoring.
        }
    }

    func notify(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

struct NullNotificationService: UserNotifying {
    func requestAuthorization() async {}
    func notify(title: String, body: String) async {}
}
