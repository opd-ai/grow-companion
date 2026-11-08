//
//  Treatment.swift
//  Grow Companion
//
//  A grower's record of a treatment applied to a plant or room.
//

import Foundation
import SwiftData

@Model
final class Treatment {
    var productName: String = ""
    var dose: String = ""
    var date: Date = Date()
    var withdrawalDays: Int?
    var note: String = ""
    var plant: Plant?
    var room: Room?

    init(
        productName: String = "",
        dose: String = "",
        date: Date = Date(),
        withdrawalDays: Int? = nil,
        note: String = "",
        plant: Plant? = nil,
        room: Room? = nil
    ) {
        self.productName = productName
        self.dose = dose
        self.date = date
        self.withdrawalDays = withdrawalDays
        self.note = note
        self.plant = plant
        self.room = room
    }

    var withdrawalEndDate: Date? {
        guard let withdrawalDays, withdrawalDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: withdrawalDays, to: date)
    }

    var isWithdrawalActive: Bool {
        guard let end = withdrawalEndDate else { return false }
        return Date() < end
    }
}
