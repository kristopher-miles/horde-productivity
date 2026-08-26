import Foundation
import UserNotifications

enum NotificationDestination: Equatable {
    case resolution(String)
    case chronicle(String)
    case goal(String)
    case stale

    static func resolve(occurrenceID: String?, eventID: String?, occurrences: [GoalOccurrenceSummary], pendingStories: [PendingStorySummary], chronicle: [ChronicleSummary]) -> Self {
        if let eventID, let pending = pendingStories.first(where: { $0.id == eventID }) { return .resolution(pending.id) }
        if let eventID, let entry = chronicle.first(where: { $0.eventID == eventID }) { return .chronicle(entry.id) }
        guard let occurrenceID else { return .stale }
        if let pending = pendingStories.first(where: { $0.id.hasPrefix(occurrenceID + ":") }) { return .resolution(pending.id) }
        if let entry = chronicle.first(where: { $0.eventID.hasPrefix(occurrenceID + ":") }) { return .chronicle(entry.id) }
        if let occurrence = occurrences.first(where: { $0.id == occurrenceID }), occurrence.state == .pending { return .goal(occurrence.definitionID) }
        return .stale
    }
}

@MainActor final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    var onTarget: ((String?, String?) -> Void)?

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let occurrenceID = response.notification.request.content.userInfo["occurrenceID"] as? String
        let eventID = response.notification.request.content.userInfo["eventID"] as? String
        Task { @MainActor in
            NotificationRouter.shared.onTarget?(occurrenceID, eventID)
            completionHandler()
        }
    }
}
