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
        if days < 0 { return "Overdue \(abs(days)) day\(abs(days) == 1 ? "" : "s")" }
        if days == 0 { return "Due today" }
        return "Due in \(days) day\(days == 1 ? "" : "s")"
    }

    static func intervalText(_ days: Int) -> String {
        "Every \(days) days"
    }
}
