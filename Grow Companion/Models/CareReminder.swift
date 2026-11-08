//
//  CareReminder.swift
//  Grow Companion
//
//  A scheduled watering, feeding, reading or calibration prompt. Each reminder
//  carries its own local notification identifier.
//

import Foundation
import SwiftData

@Model
final class CareReminder {
    var title: String = ""
    var kindRaw: String = CareReminderKind.water.rawValue
    var timeOfDayMinutes: Int = 540
    var repeatDays: Int = 1
    var isEnabled: Bool = true
    var lastCompletedAt: Date?
    var nextDueDate: Date = Date()
    var notificationIdentifier: String = UUID().uuidString
    var room: Room?

    init(
        title: String = "",
        kind: CareReminderKind = .water,
        timeOfDayMinutes: Int = 540,
        repeatDays: Int = 1,
        isEnabled: Bool = true,
        lastCompletedAt: Date? = nil,
        nextDueDate: Date = Date(),
        room: Room? = nil
    ) {
        self.title = title
        self.kindRaw = kind.rawValue
        self.timeOfDayMinutes = timeOfDayMinutes
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
        self.lastCompletedAt = lastCompletedAt
        self.nextDueDate = nextDueDate
        self.room = room
    }

    var kind: CareReminderKind {
        get { CareReminderKind(rawValue: kindRaw) ?? .water }
        set { kindRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.title : trimmed
    }

    var isDue: Bool {
        isEnabled && nextDueDate <= Date()
    }

    var repeatLabel: String {
        repeatDays == 1 ? "Every day" : "Every \(repeatDays) days"
    }
}
