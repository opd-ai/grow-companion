//
//  CycleMetrics.swift
//  Grow Companion
//
//  One finished cycle reduced to the numbers the comparison screen puts side
//  by side. A cycle is either a harvested plant or the average of a strain's
//  finished plants.
//

import Foundation

struct CycleSnapshot {
    let title: String
    let subtitle: String
    let harvestDate: Date?
    let roomName: String?
    let dryYieldGrams: Double?
    let gramsPerWatt: Double?
    let dryToWetRatio: Double?
    let daysInFlower: Int?
    let feedVolumeLiters: Double?
    let rating: Double?
    let tastingNotes: String
    let isAverage: Bool
    let sampleCount: Int
}

enum CycleSource {
    case plant(Plant)
    case strainAverage(Strain)

    var plant: Plant? {
        if case .plant(let plant) = self { return plant }
        return nil
    }

    var strain: Strain? {
        if case .strainAverage(let strain) = self { return strain }
        return nil
    }
}

enum CycleMetrics {
    /// A plant counts as a finished cycle once it has been harvested.
    static func isFinished(_ plant: Plant) -> Bool {
        plant.harvestedAt != nil || [.harvest, .cure, .storage].contains(plant.stage)
    }

    static func harvestDate(for plant: Plant) -> Date? {
        plant.sortedStageEvents.last(where: { $0.stage == .harvest })?.date ?? plant.harvestedAt
    }

    static func snapshot(for source: CycleSource) -> CycleSnapshot? {
        switch source {
        case .plant(let plant):
            return snapshot(for: plant)
        case .strainAverage(let strain):
            return average(for: strain)
        }
    }

    static func snapshot(for plant: Plant) -> CycleSnapshot {
        let dry = plant.dryWeightGrams
        let wet = plant.wetWeightGrams

        var ratio: Double?
        if let dry, let wet, wet > 0 {
            ratio = dry / wet
        }

        return CycleSnapshot(
            title: plant.displayName,
            subtitle: plant.displayStrain,
            harvestDate: harvestDate(for: plant),
            roomName: plant.room?.name,
            dryYieldGrams: dry,
            gramsPerWatt: HarvestLog.gramsPerWatt(dryGrams: dry, watts: plant.room?.lightWatts ?? 0),
            dryToWetRatio: ratio,
            daysInFlower: StrainInsights.floweringDays(for: plant),
            feedVolumeLiters: feedVolume(for: plant),
            rating: plant.rating.map { Double($0) },
            tastingNotes: plant.tastingNotes,
            isAverage: false,
            sampleCount: 1
        )
    }

    static func canAverage(_ strain: Strain) -> Bool {
        strain.plants.contains { isFinished($0) }
    }

    static func average(for strain: Strain) -> CycleSnapshot? {
        let finished = strain.plants.filter { isFinished($0) }
        guard !finished.isEmpty else { return nil }

        let snapshots = finished.map { snapshot(for: $0) }

        let mostRecentNote = finished
            .filter { !$0.tastingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                (harvestDate(for: $0) ?? .distantPast) > (harvestDate(for: $1) ?? .distantPast)
            }
            .first?
            .tastingNotes ?? ""

        let averageDays = average(snapshots.compactMap { $0.daysInFlower.map { Double($0) } })

        return CycleSnapshot(
            title: "\(strain.displayName) average",
            subtitle: "Your own completed cycles",
            harvestDate: nil,
            roomName: nil,
            dryYieldGrams: average(snapshots.compactMap { $0.dryYieldGrams }),
            gramsPerWatt: average(snapshots.compactMap { $0.gramsPerWatt }),
            dryToWetRatio: average(snapshots.compactMap { $0.dryToWetRatio }),
            daysInFlower: averageDays.map { Int($0.rounded()) },
            feedVolumeLiters: average(snapshots.compactMap { $0.feedVolumeLiters }),
            rating: average(snapshots.compactMap { $0.rating }),
            tastingNotes: mostRecentNote,
            isAverage: true,
            sampleCount: finished.count
        )
    }

    /// Feed and watering are logged per room, so a cycle's feed volume is what
    /// was logged for its room between the flower event and the harvest.
    static func feedVolume(for plant: Plant) -> Double? {
        guard let room = plant.room,
              let flowering = plant.sortedStageEvents.first(where: { $0.stage == .flower })?.date,
              let harvested = harvestDate(for: plant)
        else { return nil }

        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: harvested)) ?? harvested

        let volumes = room.feedEvents
            .filter { $0.date >= flowering && $0.date < end }
            .compactMap { $0.volumeLiters }

        guard !volumes.isEmpty else { return nil }
        return volumes.reduce(0, +)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
