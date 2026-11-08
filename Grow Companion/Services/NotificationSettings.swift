//
//  NotificationSettings.swift
//  Grow Companion
//
//  Priority per notification category, quiet hours and the generic
//  lock-screen copy that never names a plant or a room.
//

import Foundation
import UserNotifications

enum NotificationPriority: String, CaseIterable, Identifiable, Hashable {
    case critical
    case timeSensitive
    case routine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .critical: return String(localized: "Critical")
        case .timeSensitive: return String(localized: "Time-sensitive")
        case .routine: return String(localized: "Routine")
        }
    }

    var subtitle: String {
        switch self {
        case .critical: return String(localized: "Skips the app's quiet hours and arrives with sound")
        case .timeSensitive: return String(localized: "Arrives with sound, waits for quiet hours to end")
        case .routine: return String(localized: "Arrives quietly, waits for quiet hours to end")
        }
    }

    var interruptionLevel: UNNotificationInterruptionLevel {
        switch self {
        case .critical, .timeSensitive: return .timeSensitive
        case .routine: return .passive
        }
    }

    var playsSound: Bool { self != .routine }

    var relevanceScore: Double {
        switch self {
        case .critical: return 1.0
        case .timeSensitive: return 0.75
        case .routine: return 0.25
        }
    }
}

enum NotificationCategory: String, CaseIterable, Identifiable {
    case watering
    case feeding
    case readings
    case calibration
    case curing
    case compliance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .watering: return String(localized: "Watering")
        case .feeding: return String(localized: "Feeding")
        case .readings: return String(localized: "Environment readings")
        case .calibration: return String(localized: "Meter calibration")
        case .curing: return String(localized: "Curing checks")
        case .compliance: return String(localized: "Compliance status")
        }
    }

    var subtitle: String {
        switch self {
        case .watering: return String(localized: "Watering reminders")
        case .feeding: return String(localized: "Feed and reservoir reminders")
        case .readings: return String(localized: "Temperature, humidity and light prompts")
        case .calibration: return String(localized: "pH meter and EC probe reminders")
        case .curing: return String(localized: "Jar burping after harvest")
        case .compliance: return String(localized: "When your status moves towards a limit")
        }
    }

    var systemImage: String {
        switch self {
        case .watering: return "drop"
        case .feeding: return "flask"
        case .readings: return "thermometer.medium"
        case .calibration: return "gauge.with.dots.needle.50percent"
        case .curing: return "hourglass"
        case .compliance: return "checkmark.seal"
        }
    }

    var defaultPriority: NotificationPriority {
        switch self {
        case .watering, .feeding: return .timeSensitive
        case .readings, .calibration: return .routine
        case .curing, .compliance: return .timeSensitive
        }
    }

    init(reminderKind: CareReminderKind) {
        switch reminderKind {
        case .water: self = .watering
        case .feed: self = .feeding
        case .reading: self = .readings
        case .calibration: self = .calibration
        }
    }
}

enum NotificationSettings {
    // MARK: Priorities

    static func priority(for category: NotificationCategory) -> NotificationPriority {
        let key = SettingsKey.notificationPriorityPrefix + category.rawValue
        let raw = UserDefaults.standard.string(forKey: key)
        return raw.flatMap(NotificationPriority.init(rawValue:)) ?? category.defaultPriority
    }

    static func setPriority(_ priority: NotificationPriority, for category: NotificationCategory) {
        UserDefaults.standard.set(
            priority.rawValue,
            forKey: SettingsKey.notificationPriorityPrefix + category.rawValue
        )
    }

    // MARK: Generic content

    static var usesGenericContent: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.genericNotificationContent) as? Bool ?? true
    }

    static func setGenericContent(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: SettingsKey.genericNotificationContent)
    }

    // MARK: Quiet hours

    static var quietHoursEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.quietHoursEnabled) as? Bool ?? false
    }

    static var quietHoursStart: Int {
        UserDefaults.standard.object(forKey: SettingsKey.quietHoursStart) as? Int ?? 22 * 60
    }

    static var quietHoursEnd: Int {
        UserDefaults.standard.object(forKey: SettingsKey.quietHoursEnd) as? Int ?? 7 * 60
    }

    static func saveQuietHours(enabled: Bool, startMinutes: Int, endMinutes: Int) {
        UserDefaults.standard.set(enabled, forKey: SettingsKey.quietHoursEnabled)
        UserDefaults.standard.set(startMinutes, forKey: SettingsKey.quietHoursStart)
        UserDefaults.standard.set(endMinutes, forKey: SettingsKey.quietHoursEnd)
    }

    /// Returns every notification preference to its default, for the erase flow.
    static func resetToDefaults() {
        let defaults = UserDefaults.standard
        for category in NotificationCategory.allCases {
            defaults.removeObject(forKey: SettingsKey.notificationPriorityPrefix + category.rawValue)
        }
        defaults.removeObject(forKey: SettingsKey.genericNotificationContent)
        defaults.removeObject(forKey: SettingsKey.quietHoursEnabled)
        defaults.removeObject(forKey: SettingsKey.quietHoursStart)
        defaults.removeObject(forKey: SettingsKey.quietHoursEnd)
        defaults.removeObject(forKey: SettingsKey.careDigestEnabled)
        defaults.removeObject(forKey: SettingsKey.careDigestTime)
        defaults.removeObject(forKey: SettingsKey.careDigestRoomIDs)
    }

    /// Moves a reminder that would land inside quiet hours to the end of the
    /// window. Critical reminders always fire on time.
    static func adjustedFireDate(_ date: Date, priority: NotificationPriority) -> Date {
        guard quietHoursEnabled, priority != .critical else { return date }

        let start = quietHoursStart
        let end = quietHoursEnd
        guard start != end else { return date }

        let calendar = Calendar.current
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        let isQuiet: Bool
        if start < end {
            isQuiet = minute >= start && minute < end
        } else {
            isQuiet = minute >= start || minute < end
        }
        guard isQuiet else { return date }

        let startOfDay = calendar.startOfDay(for: date)
        var endDay = startOfDay
        if start > end && minute >= start {
            endDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        }

        return calendar.date(bySettingHour: end / 60, minute: end % 60, second: 0, of: endDay) ?? date
    }

    // MARK: Delivery

    static func schedule(
        identifier: String,
        category: NotificationCategory,
        title: String,
        body: String,
        at date: Date
    ) {
        let priority = priority(for: category)
        let content = UNMutableNotificationContent()

        let appLockEnabled = UserDefaults.standard.bool(forKey: SettingsKey.appLockEnabled)
        if usesGenericContent || appLockEnabled {
            content.title = "Grow Companion"
            content.body = "A care task is due. Open the app to see it."
        } else {
            content.title = title
            content.body = body
        }

        if priority.playsSound {
            content.sound = .default
        }
        content.interruptionLevel = priority.interruptionLevel
        content.relevanceScore = priority.relevanceScore

        let fireDate = max(adjustedFireDate(date, priority: priority), Date().addingTimeInterval(60))
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
