import Foundation
import UserNotifications

@MainActor
final class LocalNotificationService {
    static let shared = LocalNotificationService()

    private var sentKeys: [String: Date] = [:]
    private let defaultCooldown: TimeInterval = 5 * 60

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return
        }
    }

    func notify(title: String, body: String, key: String, cooldown: TimeInterval? = nil) {
        let now = Date()
        let effectiveCooldown = cooldown ?? defaultCooldown
        if let lastSent = sentKeys[key], now.timeIntervalSince(lastSent) < effectiveCooldown {
            return
        }
        sentKeys[key] = now

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "crbhub.\(key).\(Int(now.timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
