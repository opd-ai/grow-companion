//
//  StrainInsights.swift
//  Grow Companion
//
//  Flowering time built from the grower's own completed cycles: how long a
//  strain actually flowered, set against the breeder's figure.
//

import Foundation
import SwiftData

/// One finished flowering cycle: the flower stage event to the harvest event.
struct FloweringObservation: Identifiable {
    let plant: Plant
    let days: Int

    var id: PersistentIdentifier { plant.persistentModelID }
}

struct FloweringExpectation {
    enum Source: Equatable {
        case observed
        case breeder
        case typical
    }

    let days: Int
    let source: Source
    let sampleCount: Int

    var weeks: Int {
        max(1, Int((Double(days) / 7).rounded()))
    }

    /// True when the figure comes from the grower's own finished cycles.
    var usesHistory: Bool {
        source == .observed && sampleCount > 0
    }

    var sourceText: String {
        switch source {
        case .observed:
            let cycles = sampleCount == 1
                ? "one of your completed cycles"
                : "\(sampleCount) of your completed cycles"
            return "Using \(Format.dayCount(days)) observed across \(cycles) — your own timing, not the breeder's label."
        case .breeder:
            return "Using the breeder's expected \(weeks) weeks. Your own observed timing replaces it once a cycle finishes."
        case .typical:
            return "No strain history yet. Using the usual \(weeks) weeks for flowering."
        }
    }
}

enum StrainInsights {
    /// Grace beyond the expected figure before a plant is flagged.
    static let graceDays = 7

    static var defaultFloweringDays: Int {
        PlantStage.flower.expectedDays ?? 63
    }

    // MARK: Per-plant measurement

    /// Days spent in flower for a plant that has both a flower and a harvest
    /// event. Nil while the cycle is still running.
    static func floweringDays(for plant: Plant) -> Int? {
        let events = plant.sortedStageEvents
        guard let flower = events.first(where: { $0.stage == .flower }) else { return nil }
        let harvestDate = events.first(where: { $0.stage == .harvest })?.date ?? plant.harvestedAt
        guard let harvestDate, harvestDate > flower.date else { return nil }

        let calendar = Calendar.current
        let from = calendar.startOfDay(for: flower.date)
        let to = calendar.startOfDay(for: harvestDate)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return days > 0 ? days : nil
    }

    static func observations(for strain: Strain) -> [FloweringObservation] {
        strain.plants
            .compactMap { plant in
                guard let days = floweringDays(for: plant) else { return nil }
                return FloweringObservation(plant: plant, days: days)
            }
            .sorted { $0.plant.plantedAt > $1.plant.plantedAt }
    }

    static func observedAverage(for strain: Strain) -> (days: Double, count: Int)? {
        let observations = observations(for: strain)
        guard !observations.isEmpty else { return nil }
        let total = observations.reduce(0) { $0 + $1.days }
        return (Double(total) / Double(observations.count), observations.count)
    }

    // MARK: Expectations

    /// The figure a plant's flower-week counter runs on: the grower's own
    /// observed average first, then the breeder's label, then the stage default.
    static func expectation(for plant: Plant) -> FloweringExpectation {
        if let strain = plant.strain, let observed = observedAverage(for: strain) {
            return FloweringExpectation(
                days: Int(observed.days.rounded()),
                source: .observed,
                sampleCount: observed.count
            )
        }
        if let strain = plant.strain {
            return FloweringExpectation(
                days: strain.expectedFloweringDays,
                source: .breeder,
                sampleCount: 0
            )
        }
        return FloweringExpectation(days: defaultFloweringDays, source: .typical, sampleCount: 0)
    }

    static func currentFlowerWeek(for plant: Plant) -> Int {
        max(1, plant.daysInStage / 7 + 1)
    }

    // MARK: Formatting

    /// Full form for prose: "9 weeks 3 days".
    static func lengthText(days: Double) -> String {
        let total = max(0, Int(days.rounded()))
        let weeks = total / 7
        let rest = total % 7
        if weeks == 0 { return Format.dayCount(total) }
        let weekText = "\(weeks) week\(weeks == 1 ? "" : "s")"
        guard rest > 0 else { return weekText }
        return "\(weekText) \(Format.dayCount(rest))"
    }

    /// Short form for metric tiles: "9 wk 3 d".
    static func shortLengthText(days: Double) -> String {
        let total = max(0, Int(days.rounded()))
        let weeks = total / 7
        let rest = total % 7
        if weeks == 0 { return "\(total) d" }
        guard rest > 0 else { return "\(weeks) wk" }
        return "\(weeks) wk \(rest) d"
    }
}
