//
//  CareDigest.swift
//  Grow Companion
//
//  Local daily summary of recorded care and unfinished scheduled tasks.
//

import Foundation
import UserNotifications

struct CareDigestPreferences {
    var enabled: Bool
    var timeOfDayMinutes: Int
    var roomIDs: Set<String>

    static var current: CareDigestPreferences {
        let defaults = UserDefaults.standard
        let storedIDs = defaults.stringArray(forKey: SettingsKey.careDigestRoomIDs) ?? []
        return CareDigestPreferences(
            enabled: defaults.object(forKey: SettingsKey.careDigestEnabled) as? Bool ?? false,
            timeOfDayMinutes: defaults.object(forKey: SettingsKey.careDigestTime) as? Int ?? 8 * 60,
            roomIDs: Set(storedIDs)
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: SettingsKey.careDigestEnabled)
        defaults.set(timeOfDayMinutes, forKey: SettingsKey.careDigestTime)
        defaults.set(Array(roomIDs), forKey: SettingsKey.careDigestRoomIDs)
    }
}

struct CareDigestSnapshot {
    let activityStart: Date
    let activityEnd: Date
    let feedEvents: [FeedEvent]
    let environmentReadings: [EnvironmentReading]
    let calibrationEvents: [CalibrationEvent]
    let unfinishedReminders: [CareReminder]

    var activityCount: Int {
        feedEvents.count + environmentReadings.count + calibrationEvents.count
    }
}

enum CareDigest {
    static let notificationIdentifier = "care-digest"

    static func schedule(rooms: [Room]) {
        cancel()
        let preferences = CareDigestPreferences.current
        guard preferences.enabled else { return }

        let selectedRooms = selectedRooms(from: rooms, roomIDs: preferences.roomIDs)
        guard !selectedRooms.isEmpty else { return }
        let content = UNMutableNotificationContent()
        let summary = summary(for: selectedRooms, now: Date())

        if NotificationSettings.usesGenericContent || UserDefaults.standard.bool(forKey: SettingsKey.appLockEnabled) {
            content.title = "Grow Companion"
            content.body = "Your daily care digest is ready. Open the app to see it."
        } else {
            content.title = "Daily care digest"
            content.body = summary
        }

        let priority = NotificationSettings.priority(for: .readings)
        content.interruptionLevel = priority.interruptionLevel
        content.relevanceScore = priority.relevanceScore
        if priority.playsSound { content.sound = .default }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let requested = calendar.date(
            bySettingHour: preferences.timeOfDayMinutes / 60,
            minute: preferences.timeOfDayMinutes % 60,
            second: 0,
            of: today
        ) ?? Date()
        let fireDate = NotificationSettings.adjustedFireDate(requested, priority: priority)
        var components = calendar.dateComponents([.hour, .minute], from: fireDate)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    static func roomID(_ room: Room) -> String {
        String(describing: room.persistentModelID)
    }

    static func selectedRooms(from rooms: [Room], roomIDs: Set<String>) -> [Room] {
        rooms.filter { roomIDs.contains(roomID($0)) }
    }

    /// For the selected rooms, a digest dated `digestDate` includes the prior
    /// calendar day's care records and reminders already overdue at day start.
    static func snapshot(for rooms: [Room], digestDate: Date) -> CareDigestSnapshot {
        let calendar = Calendar.current
        let digestDayStart = calendar.startOfDay(for: digestDate)
        let activityStart = calendar.date(byAdding: .day, value: -1, to: digestDayStart) ?? digestDayStart
        let selected = rooms

        return CareDigestSnapshot(
            activityStart: activityStart,
            activityEnd: digestDayStart,
            feedEvents: selected.flatMap(\.feedEvents)
                .filter { $0.date >= activityStart && $0.date < digestDayStart }
                .sorted { $0.date > $1.date },
            environmentReadings: selected.flatMap(\.environmentReadings)
                .filter { $0.date >= activityStart && $0.date < digestDayStart }
                .sorted { $0.date > $1.date },
            calibrationEvents: selected.flatMap(\.calibrationEvents)
                .filter { $0.date >= activityStart && $0.date < digestDayStart }
                .sorted { $0.date > $1.date },
            unfinishedReminders: selected.flatMap(\.careReminders)
                .filter { $0.isEnabled && $0.nextDueDate < digestDayStart }
                .sorted { $0.nextDueDate < $1.nextDueDate }
        )
    }

    static func summary(for rooms: [Room], now: Date) -> String {
        let snapshot = snapshot(for: rooms, digestDate: now)
        let activity = snapshot.activityCount
        let unfinished = snapshot.unfinishedReminders.count

        if activity == 0 && unfinished == 0 { return String(localized: "No care activity recorded. Nothing is overdue.") }
        if activity == 0 { return String(localized: "No care activity recorded. \(unfinished) scheduled task\(unfinished == 1 ? "" : "s") remain unfinished.") }
        if unfinished == 0 { return String(localized: "\(activity) care record\(activity == 1 ? "" : "s") recorded. No scheduled tasks remain unfinished.") }
        let tasks = String(localized: "\(unfinished) scheduled task\(unfinished == 1 ? "" : "s") remain unfinished.")
        return String(localized: "\(activity) care record\(activity == 1 ? "" : "s") recorded. \(tasks)")
    }
}
