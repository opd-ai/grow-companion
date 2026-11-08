//
//  StageEvent.swift
//  Grow Companion
//
//  One timestamped stage transition for a plant. The history is the record the
//  flower-week counter and every later timing metric are built on.
//

import Foundation
import SwiftData

@Model
final class StageEvent {
    var stageRaw: String = PlantStage.seed.rawValue
    var date: Date = Date()
    var note: String = ""
    var isBackfilled: Bool = false
    var plant: Plant?

    init(
        stage: PlantStage,
        date: Date = Date(),
        note: String = "",
        isBackfilled: Bool = false,
        plant: Plant? = nil
    ) {
        self.stageRaw = stage.rawValue
        self.date = date
        self.note = note
        self.isBackfilled = isBackfilled
        self.plant = plant
    }

    var stage: PlantStage {
        get { PlantStage(rawValue: stageRaw) ?? .seed }
        set { stageRaw = newValue.rawValue }
    }
}
