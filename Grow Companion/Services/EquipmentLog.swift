//
//  EquipmentLog.swift
//  Grow Companion
//
//  Display helpers for service reminders.
//

import Foundation

enum EquipmentLog {
    static func dueText(for equipment: Equipment) -> String {
        let days = equipment.daysUntilService
        if days < 0 { return String(localized: "Overdue \(abs(days)) day\(abs(days) == 1 ? "" : "s")") }
        if days == 0 { return String(localized: "Due today") }
        return String(localized: "Due in \(days) day\(days == 1 ? "" : "s")")
    }

    static func intervalText(_ days: Int) -> String {
        "Every \(days) days"
    }
}
