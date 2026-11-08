//
//  CalibrationEvent.swift
//  Grow Companion
//
//  A pH meter or EC probe calibration, with the next due date for the meter.
//

import Foundation
import SwiftData

@Model
final class CalibrationEvent {
    var date: Date = Date()
    var meterRaw: String = CalibrationMeter.phMeter.rawValue
    var reading: Double?
    var note: String = ""
    var nextDueDate: Date?
    var room: Room?

    init(
        date: Date = Date(),
        meter: CalibrationMeter = .phMeter,
        reading: Double? = nil,
        note: String = "",
        nextDueDate: Date? = nil,
        room: Room? = nil
    ) {
        self.date = date
        self.meterRaw = meter.rawValue
        self.reading = reading
        self.note = note
        self.nextDueDate = nextDueDate
        self.room = room
    }

    var meter: CalibrationMeter {
        get { CalibrationMeter(rawValue: meterRaw) ?? .phMeter }
        set { meterRaw = newValue.rawValue }
    }
}
