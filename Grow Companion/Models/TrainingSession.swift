//
//  TrainingSession.swift
//  Grow Companion
//
//  One training session on a plant: topping, LST, defoliation, supercropping
//  or a SCROG tuck, with the date, nodes affected and a note.
//

import Foundation
import SwiftData

@Model
final class TrainingSession {
    var methodRaw: String = TrainingMethod.topping.rawValue
    var date: Date = Date()
    var nodesAffected: Int?
    var note: String = ""
    var plant: Plant?

    init(
        method: TrainingMethod = .topping,
        date: Date = Date(),
        nodesAffected: Int? = nil,
        note: String = "",
        plant: Plant? = nil
    ) {
        self.methodRaw = method.rawValue
        self.date = date
        self.nodesAffected = nodesAffected
        self.note = note
        self.plant = plant
    }

    var method: TrainingMethod {
        get { TrainingMethod(rawValue: methodRaw) ?? .topping }
        set { methodRaw = newValue.rawValue }
    }
}
