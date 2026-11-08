//
//  PlantRemovalService.swift
//  Grow Companion
//
//  Removing a plant offers two outcomes: archive it, which keeps every record
//  and moves it out of the active garden, or delete it and its own history.
//  Journal entries are never deleted — they stay without a plant link.
//

import Foundation
import SwiftData

enum PlantRemovalChoice {
    case archive
    case delete

    var isDestructive: Bool { self == .delete }
}

/// What a deletion would take with it, for the confirmation and the tests.
struct PlantRemovalSummary: Equatable {
    let journalEntriesKept: Int
    let stageEvents: Int
    let trainingSessions: Int
    let treatments: Int
    let scoutingChecks: Int
    let dryingSessions: Int

    var recordsRemoved: Int {
        stageEvents + trainingSessions + treatments + scoutingChecks + dryingSessions
    }
}

enum PlantRemovalError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let detail):
            return "The plant was not changed: \(detail)"
        }
    }
}

enum PlantRemovalService {
    static func summary(for plant: Plant) -> PlantRemovalSummary {
        PlantRemovalSummary(
            journalEntriesKept: plant.journalEntries.count,
            stageEvents: plant.stageEvents.count,
            trainingSessions: plant.trainingSessions.count,
            treatments: plant.treatments.count,
            scoutingChecks: plant.scoutingChecks.count,
            dryingSessions: plant.dryingSessions.count
        )
    }

    /// Keeps every record and moves the plant out of the active garden by
    /// attaching it to a cycle archive. Nothing is deleted, so the stage, feed,
    /// environment, journal, treatment and yield history stay readable.
    @discardableResult
    static func archive(
        _ plant: Plant,
        in context: ModelContext,
        now: Date = Date()
    ) throws -> CycleArchive {
        let archive: CycleArchive
        if let existing = plant.cycleArchive {
            archive = existing
        } else {
            let created = CycleArchive(name: plant.displayName, completedAt: now)
            context.insert(created)
            plant.cycleArchive = created
            archive = created
        }

        do {
            try context.save()
            return archive
        } catch {
            context.rollback()
            throw PlantRemovalError.saveFailed(error.localizedDescription)
        }
    }

    /// Deletes the plant and the records that belong to it. Journal entries are
    /// nullified by the model's delete rule, so they survive without a link.
    static func delete(_ plant: Plant, in context: ModelContext) throws {
        context.delete(plant)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PlantRemovalError.saveFailed(error.localizedDescription)
        }
    }
}
