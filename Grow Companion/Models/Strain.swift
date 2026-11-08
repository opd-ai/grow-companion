//
//  Strain.swift
//  Grow Companion
//
//  A cultivar in the library: the breeder's figures, the plants grown from it
//  and the ratings its harvests were given.
//

import Foundation
import SwiftData

@Model
final class Strain {
    var name: String = ""
    var breeder: String = ""
    var typeRaw: String = StrainType.hybrid.rawValue

    /// The breeder's expected flowering window, in whole weeks.
    var expectedFloweringWeeks: Int = 9
    var claimedYield: String = ""
    var parentLines: String = ""
    var lineageStatusRaw: String = LineageStatus.missing.rawValue
    var breederSource: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Plant.strain)
    var plants: [Plant] = []

    init(
        name: String = "",
        breeder: String = "",
        type: StrainType = .hybrid,
        expectedFloweringWeeks: Int = 9,
        claimedYield: String = "",
        parentLines: String = "",
        lineageStatus: LineageStatus = .missing,
        breederSource: String = "",
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.name = name
        self.breeder = breeder
        self.typeRaw = type.rawValue
        self.expectedFloweringWeeks = expectedFloweringWeeks
        self.claimedYield = claimedYield
        self.parentLines = parentLines
        self.lineageStatusRaw = lineageStatus.rawValue
        self.breederSource = breederSource
        self.notes = notes
        self.createdAt = createdAt
    }

    var lineageStatus: LineageStatus {
        get { LineageStatus(rawValue: lineageStatusRaw) ?? .missing }
        set { lineageStatusRaw = newValue.rawValue }
    }

    var type: StrainType {
        get { StrainType(rawValue: typeRaw) ?? .hybrid }
        set { typeRaw = newValue.rawValue }
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed strain" : trimmed
    }

    var displayBreeder: String {
        let trimmed = breeder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Breeder not recorded" : trimmed
    }

    /// The breeder's figure in days, used until the grower has a finished cycle.
    var expectedFloweringDays: Int {
        max(1, expectedFloweringWeeks) * 7
    }

    var floweringLabel: String {
        "\(max(1, expectedFloweringWeeks)) weeks"
    }

    /// Every plant assigned to this strain, newest first.
    var sortedPlants: [Plant] {
        plants.sorted { $0.plantedAt > $1.plantedAt }
    }

    var activePlants: [Plant] {
        sortedPlants.filter { $0.isActive }
    }

    var ratedPlants: [Plant] {
        plants
            .filter { $0.rating != nil }
            .sorted { ($0.ratedAt ?? $0.plantedAt) > ($1.ratedAt ?? $1.plantedAt) }
    }

    var averageRating: Double? {
        let values = plants.compactMap { $0.rating }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}
