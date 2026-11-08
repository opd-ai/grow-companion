//
//  Plant.swift
//  Grow Companion
//

import Foundation
import SwiftData

@Model
final class Plant {
    var name: String = ""
    var strainName: String = ""
    var originRaw: String = PlantOrigin.seed.rawValue
    var stageRaw: String = PlantStage.seed.rawValue
    var container: String = ""
    var plantedAt: Date = Date()
    var notes: String = ""
    var isMother: Bool = false
    var wetWeightGrams: Double?
    var dryWeightGrams: Double?
    var harvestDispositionRaw: String?
    var harvestedAt: Date?
    var room: Room?
    var cycleArchive: CycleArchive?

    /// The cultivar this plant was assigned from the strain library.
    var strain: Strain?

    /// The plant this clone or cutting was taken from.
    var mother: Plant?

    @Relationship(deleteRule: .nullify, inverse: \Plant.mother)
    var clones: [Plant] = []

    /// 1–5, set after harvest and cure. Nil until the grower judges the result.
    var ratingRaw: Int?
    var tastingNotes: String = ""
    var ratedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \StageEvent.plant)
    var stageEvents: [StageEvent] = []

    @Relationship(deleteRule: .nullify, inverse: \JournalEntry.plant)
    var journalEntries: [JournalEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \DryingSession.plant)
    var dryingSessions: [DryingSession] = []

    @Relationship(deleteRule: .cascade, inverse: \TrainingSession.plant)
    var trainingSessions: [TrainingSession] = []

    @Relationship(deleteRule: .cascade, inverse: \Treatment.plant)
    var treatments: [Treatment] = []

    @Relationship(deleteRule: .cascade, inverse: \ScoutingCheck.plant)
    var scoutingChecks: [ScoutingCheck] = []

    init(
        name: String = "",
        strainName: String = "",
        origin: PlantOrigin = .seed,
        stage: PlantStage? = nil,
        container: String = "",
        plantedAt: Date = Date(),
        notes: String = "",
        isMother: Bool = false,
        room: Room? = nil,
        strain: Strain? = nil,
        mother: Plant? = nil
    ) {
        self.name = name
        self.strainName = strainName
        self.originRaw = origin.rawValue
        self.stageRaw = (stage ?? origin.startingStage).rawValue
        self.container = container
        self.plantedAt = plantedAt
        self.notes = notes
        self.isMother = isMother
        self.room = room
        self.strain = strain
        self.mother = mother
    }

    var stage: PlantStage {
        get { PlantStage(rawValue: stageRaw) ?? .seed }
        set { stageRaw = newValue.rawValue }
    }

    var origin: PlantOrigin {
        get { PlantOrigin(rawValue: originRaw) ?? .seed }
        set { originRaw = newValue.rawValue }
    }

    var harvestDisposition: HarvestDisposition? {
        get {
            guard let raw = harvestDispositionRaw else { return nil }
            return HarvestDisposition(rawValue: raw)
        }
        set { harvestDispositionRaw = newValue?.rawValue }
    }

    /// The grower's own verdict on the finished flower, 1–5.
    var rating: Int? {
        get { ratingRaw }
        set { ratingRaw = newValue }
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed plant" : trimmed
    }

    var displayStrain: String {
        if let strain {
            let trimmed = strain.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let trimmed = strainName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No strain recorded" : trimmed
    }

    var sortedStageEvents: [StageEvent] {
        stageEvents.sorted { $0.date < $1.date }
    }

    /// When the current stage began: the most recent stage event, falling back
    /// to when the plant was created.
    var stageStartedAt: Date {
        sortedStageEvents.last?.date ?? plantedAt
    }

    var daysInStage: Int {
        let days = Calendar.current.dateComponents([.day], from: stageStartedAt, to: Date()).day ?? 0
        return max(0, days)
    }

    /// True once a plant has sat in a stage well past its typical duration.
    var isStageOverdue: Bool {
        guard let expected = stage.expectedDays else { return false }
        return daysInStage > expected
    }

    /// True for plants that are still part of the active garden.
    var isActive: Bool {
        cycleArchive == nil && stage != .storage && harvestDisposition != .destroyed
    }

    var isArchived: Bool { cycleArchive != nil }

    /// Harvested flower still kept at home, used for the possession metric.
    var retainedDryWeightGrams: Double {
        guard dryWeightGrams != nil else { return 0 }
        switch harvestDisposition {
        case .some(.destroyed), .some(.consumedAtHome):
            return 0
        default:
            return dryWeightGrams ?? 0
        }
    }

    var sortedDryingSessions: [DryingSession] {
        dryingSessions.sorted { $0.startedAt > $1.startedAt }
    }

    var activeDryingSession: DryingSession? {
        sortedDryingSessions.first { $0.isActive }
    }

    // MARK: Training

    /// Every training session on this plant, newest first.
    var sortedTrainingSessions: [TrainingSession] {
        trainingSessions.sorted { $0.date > $1.date }
    }

    /// Treatments applied directly to this plant or to its room.
    var allTreatments: [Treatment] {
        treatments + (room?.treatments ?? [])
    }

    var lastTrainingDate: Date? {
        sortedTrainingSessions.first?.date
    }

    // MARK: Lineage

    /// Every direct clone taken from this plant, newest first.
    var sortedClones: [Plant] {
        clones.sorted { $0.plantedAt > $1.plantedAt }
    }

    /// How many generations down from a seed this plant is. A seed is 0.
    var generation: Int {
        var level = 0
        var seen: Set<PersistentIdentifier> = [persistentModelID]
        var current = mother

        while let parent = current, level < 32 {
            guard !seen.contains(parent.persistentModelID) else { break }
            seen.insert(parent.persistentModelID)
            level += 1
            current = parent.mother
        }

        return level
    }

    /// The plant at the top of this lineage: the original seed or mother.
    var familyRoot: Plant {
        var current = self
        var seen: Set<PersistentIdentifier> = [persistentModelID]

        while let parent = current.mother {
            guard !seen.contains(parent.persistentModelID) else { break }
            seen.insert(parent.persistentModelID)
            current = parent
        }

        return current
    }

    /// Every clone below this plant, at any depth.
    func descendants() -> [Plant] {
        var result: [Plant] = []
        var queue = clones
        var seen: Set<PersistentIdentifier> = [persistentModelID]

        while let next = queue.popLast() {
            guard !seen.contains(next.persistentModelID) else { continue }
            seen.insert(next.persistentModelID)
            result.append(next)
            queue.append(contentsOf: next.clones)
        }

        return result
    }
}
