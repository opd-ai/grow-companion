//
//  ScoutingCheck.swift
//  Grow Companion
//
//  A dated plant or room observation with optional findings, note and photo.
//

import Foundation
import SwiftData

@Model
final class ScoutingCheck {
    var date: Date = Date()
    var findingRaws: [String] = []
    var note: String = ""
    var photoFileName: String?
    var plant: Plant?
    var room: Room?

    init(
        date: Date = Date(),
        findings: [ObservationTag] = [],
        note: String = "",
        photoFileName: String? = nil,
        plant: Plant? = nil,
        room: Room? = nil
    ) {
        self.date = date
        self.findingRaws = findings.map(\.rawValue)
        self.note = note
        self.photoFileName = photoFileName
        self.plant = plant
        self.room = room
    }

    var findings: [ObservationTag] {
        get { findingRaws.compactMap(ObservationTag.init(rawValue:)) }
        set { findingRaws = newValue.map(\.rawValue) }
    }
}
