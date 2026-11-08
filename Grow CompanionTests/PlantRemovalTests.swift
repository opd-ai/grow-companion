//
//  PlantRemovalTests.swift
//  Grow CompanionTests
//
//  Removing a plant either archives it with every record intact or deletes the
//  plant and the records that belong to it, leaving journal entries behind.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct PlantRemovalTests {
    @Test func archivingKeepsEveryRecordAndLeavesTheActiveGarden() throws {
        let context = try removalContext()
        let room = Room(name: "Tent")
        context.insert(room)

        let plant = Plant(name: "Blue Dream", stage: .flower, room: room)
        context.insert(plant)
        context.insert(StageEvent(stage: .flower, date: Date(), plant: plant))
        context.insert(JournalEntry(kind: .note, text: "Pale leaves", plant: plant))
        context.insert(TrainingSession(method: .topping, plant: plant))
        context.insert(Treatment(productName: "Neem", plant: plant))
        context.insert(ScoutingCheck(findings: [.pests], plant: plant))
        try context.save()

        let archive = try PlantRemovalService.archive(plant, in: context)

        #expect(plant.cycleArchive?.persistentModelID == archive.persistentModelID)
        #expect(plant.isActive == false)
        #expect(plant.stageEvents.count == 1)
        #expect(plant.journalEntries.count == 1)
        #expect(plant.trainingSessions.count == 1)
        #expect(plant.treatments.count == 1)
        #expect(plant.scoutingChecks.count == 1)
        #expect(archive.sortedPlants.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<Plant>()) == 1)
    }

    @Test func archivingTwiceReusesTheSameArchive() throws {
        let context = try removalContext()
        let plant = Plant(name: "One", stage: .veg)
        context.insert(plant)
        try context.save()

        let first = try PlantRemovalService.archive(plant, in: context)
        let second = try PlantRemovalService.archive(plant, in: context)

        #expect(first.persistentModelID == second.persistentModelID)
        #expect(try context.fetchCount(FetchDescriptor<CycleArchive>()) == 1)
    }

    @Test func deletingRemovesThePlantAndItsRecordsButKeepsTheJournal() throws {
        let context = try removalContext()
        let plant = Plant(name: "One", stage: .flower)
        context.insert(plant)
        context.insert(StageEvent(stage: .flower, date: Date(), plant: plant))
        context.insert(JournalEntry(kind: .note, text: "Two", plant: plant))
        context.insert(TrainingSession(method: .defoliation, plant: plant))
        try context.save()

        try PlantRemovalService.delete(plant, in: context)

        #expect(try context.fetchCount(FetchDescriptor<Plant>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<StageEvent>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TrainingSession>()) == 0)

        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.plant == nil)
    }

    @Test func theSummaryCountsWhatDeletionWouldRemove() throws {
        let context = try removalContext()
        let plant = Plant(name: "One", stage: .flower)
        context.insert(plant)
        context.insert(StageEvent(stage: .flower, date: Date(), plant: plant))
        context.insert(StageEvent(stage: .veg, date: Date().addingTimeInterval(-3600), plant: plant))
        context.insert(JournalEntry(kind: .note, text: "One", plant: plant))
        context.insert(Treatment(productName: "Neem", plant: plant))
        try context.save()

        let summary = PlantRemovalService.summary(for: plant)

        #expect(summary.stageEvents == 2)
        #expect(summary.treatments == 1)
        #expect(summary.journalEntriesKept == 1)
        #expect(summary.recordsRemoved == 3)
    }

    private func removalContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}

@Suite(.serialized)
struct GardenTimelineAlertTests {
    @Test func anEnvironmentAlertAppearsInTheTimelineOnce() throws {
        let context = try alertTimelineContext()
        let room = Room(name: "Tent")
        context.insert(room)

        let alert = EnvironmentAlert(
            metric: .temperature,
            value: 30,
            target: 18...24,
            detectedAt: Date(),
            room: room
        )
        context.insert(alert)
        try context.save()

        let events = GardenTimelineService.events(
            from: GardenTimelineSources(environmentAlerts: [alert])
        )

        let event = try #require(events.first)
        #expect(events.count == 1)
        #expect(event.kind == .environmentAlert)
        #expect(event.room?.persistentModelID == room.persistentModelID)
        #expect(event.title.contains("Temperature"))
        #expect(event.detail?.contains("target") == true)
    }

    private func alertTimelineContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}
