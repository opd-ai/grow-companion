//
//  Equipment.swift
//  Grow Companion
//
//  Equipment and its short service history.
//

import Foundation
import SwiftData

@Model
final class Equipment {
    var name: String = ""
    var serviceIntervalDays: Int = 90
    var lastServicedAt: Date = Date()
    var room: Room?

    @Relationship(deleteRule: .cascade, inverse: \ServiceRecord.equipment)
    var serviceRecords: [ServiceRecord] = []

    init(
        name: String = "",
        serviceIntervalDays: Int = 90,
        lastServicedAt: Date = Date(),
        room: Room? = nil
    ) {
        self.name = name
        self.serviceIntervalDays = serviceIntervalDays
        self.lastServicedAt = lastServicedAt
        self.room = room
    }

    var nextServiceDate: Date {
        Calendar.current.date(byAdding: .day, value: max(1, serviceIntervalDays), to: lastServicedAt) ?? lastServicedAt
    }

    var isOverdue: Bool { nextServiceDate < Date() }

    var daysUntilService: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: nextServiceDate)).day ?? 0
    }

    var sortedServiceRecords: [ServiceRecord] {
        serviceRecords.sorted { $0.date > $1.date }
    }
}

@Model
final class ServiceRecord {
    var date: Date = Date()
    var note: String = ""
    var equipment: Equipment?

    init(date: Date = Date(), note: String = "", equipment: Equipment? = nil) {
        self.date = date
        self.note = note
        self.equipment = equipment
    }
}
