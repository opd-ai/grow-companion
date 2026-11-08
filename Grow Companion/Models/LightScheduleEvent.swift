//
//  LightScheduleEvent.swift
//  Grow Companion
//
//  Every manual change to a room's photoperiod, kept so the grower can see
//  when a schedule moved and whether plants were flowering at the time.
//

import Foundation
import SwiftData

@Model
final class LightScheduleEvent {
    var date: Date = Date()
    var previousOnMinutes: Int = 0
    var previousOffMinutes: Int = 0
    var newOnMinutes: Int = 0
    var newOffMinutes: Int = 0
    var note: String = ""
    var hadFloweringPlants: Bool = false
    var room: Room?

    init(
        date: Date = Date(),
        previousOnMinutes: Int,
        previousOffMinutes: Int,
        newOnMinutes: Int,
        newOffMinutes: Int,
        note: String = "",
        hadFloweringPlants: Bool = false,
        room: Room? = nil
    ) {
        self.date = date
        self.previousOnMinutes = previousOnMinutes
        self.previousOffMinutes = previousOffMinutes
        self.newOnMinutes = newOnMinutes
        self.newOffMinutes = newOffMinutes
        self.note = note
        self.hadFloweringPlants = hadFloweringPlants
        self.room = room
    }

    var previousSummary: String {
        LightSchedule.summary(on: previousOnMinutes, off: previousOffMinutes)
    }

    var newSummary: String {
        LightSchedule.summary(on: newOnMinutes, off: newOffMinutes)
    }

    var previousTimes: String {
        "\(LightSchedule.timeLabel(previousOnMinutes))–\(LightSchedule.timeLabel(previousOffMinutes))"
    }

    var newTimes: String {
        "\(LightSchedule.timeLabel(newOnMinutes))–\(LightSchedule.timeLabel(newOffMinutes))"
    }
}
