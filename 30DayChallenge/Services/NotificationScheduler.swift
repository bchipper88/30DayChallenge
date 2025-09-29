import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async {
        do {
            let _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error.localizedDescription)")
        }
    }

    func scheduleDailyReminder(for rule: ReminderRule, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = "30 Day Challenge"
        content.body = rule.message
        content.sound = .default

        var components = DateComponents()
        components.calendar = Calendar.current
        components.hour = rule.timeOfDay.hour
        components.minute = rule.timeOfDay.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule notification: \(error.localizedDescription)")
        }
    }
}
