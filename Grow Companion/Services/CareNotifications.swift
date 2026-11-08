//
//  CareNotifications.swift
//  Grow Companion
//
//  Local notifications for care reminders. The lock-screen text stays generic,
//  so nothing about the grow appears on a protected screen.
//

import Foundation
import UserNotifications

enum CareNotifications {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func schedule(_ reminder: CareReminder) {
        guard reminder.isEnabled else {
            cancel(reminder)
            return
        }
        NotificationSettings.schedule(
            identifier: reminder.notificationIdentifier,
            category: NotificationCategory(reminderKind: reminder.kind),
            title: title(for: reminder.kind),
            body: "Open Grow Companion to log it.",
            at: reminder.nextDueDate
        )
    }

    /// Re-applies the notification settings to every reminder already scheduled.
    static func refresh(_ reminders: [CareReminder]) {
        for reminder in reminders where reminder.isEnabled {
            schedule(reminder)
        }
    }

    static func cancel(_ reminder: CareReminder) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminder.notificationIdentifier])
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Generic one-off notification used by the curing burp schedule.
    static func schedule(_ alert: EnvironmentAlert, room: Room, suggestedAction: String? = nil) {
        let metric = alert.metric
        let title = "\(room.name) · \(metric.title) out of range"
        var body = "\(metric.display(alert.value, unit: .metric)); target \(metric.displayTarget(alert.target, unit: .metric))."
        if let suggestedAction {
            body += " " + suggestedAction
        }
        NotificationSettings.schedule(identifier: alert.notificationIdentifier, category: .readings, title: title, body: body, at: alert.detectedAt)
    }

    static func schedule(identifier: String, title: String, body: String, at date: Date) {
        cancel(identifier: identifier)
        NotificationSettings.schedule(
            identifier: identifier,
            category: .curing,
            title: title,
            body: body,
            at: date
        )
    }

    static func cancel(identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func title(for kind: CareReminderKind) -> String {
        switch kind {
        case .water: return "Watering due"
        case .feed: return "Feeding due"
        case .reading: return "Reading due"
        case .calibration: return "Meter calibration due"
        }
    }
}
