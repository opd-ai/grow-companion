//
//  CycleArchive.swift
//  Grow Companion
//
//  A named, completed grow cycle. Archiving never deletes plant history.
//

import Foundation
import SwiftData

@Model
final class CycleArchive {
    var name: String = "Completed cycle"
    var completedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Plant.cycleArchive)
    var plants: [Plant] = []

    init(name: String = "Completed cycle", completedAt: Date = Date(), plants: [Plant] = []) {
        self.name = name
        self.completedAt = completedAt
        self.plants = plants
    }

    var sortedPlants: [Plant] { plants.sorted { $0.plantedAt < $1.plantedAt } }

    var dryYieldGrams: Double? {
        let values = plants.compactMap(\.dryWeightGrams)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    var roomSummary: String {
        let names = Array(Set(plants.compactMap { $0.room?.name })).sorted()
        return names.isEmpty ? "No room recorded" : names.joined(separator: ", ")
    }
}
