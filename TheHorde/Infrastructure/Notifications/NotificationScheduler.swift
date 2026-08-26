import Foundation
import UserNotifications

actor NotificationScheduler {
    static let shared = NotificationScheduler()
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(occurrence: GoalOccurrenceSummary, eventID: String? = nil) async throws {
        guard let due = occurrence.dueDate, due > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = occurrence.snapshot.title
        content.body = "This goal is due. Open The Horde to review it."
        content.sound = .default
        content.userInfo = ["occurrenceID": occurrence.id]
        if let eventID { content.userInfo["eventID"] = eventID }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        let request = UNNotificationRequest(identifier: occurrence.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try await center.add(request)
    }

    func cancel(occurrenceIDs: [String]) { center.removePendingNotificationRequests(withIdentifiers: occurrenceIDs) }
    func cancelAll() { center.removeAllPendingNotificationRequests() }
}
