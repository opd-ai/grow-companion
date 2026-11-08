//
//  QuickLogTests.swift
//  Grow CompanionTests
//
//  Prefill from the last record, the plant-count preview, and the single
//  write each quick action performs.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct QuickLogTests {
    @Test func feedPrefillUsesTheLatestFeedInTheRoom() throws {
        let context = try makeContext()
        let room = Room(name: "Tent")
        context.insert(room)

        let older = FeedEvent(
            date: Date().addingTimeInterval(-3600),
            kind: .feed,
            volumeLiters: 1,
            phIn: 5.9,
            ecIn: 1.2,
            room: room
        )
        let latest = FeedEvent(
            date: Date(),
            kind: .water,
            volumeLiters: 2.5,
            phIn: 6.2,
            ecIn: 1.6,
            room: room
        )
        context.insert(older)
        context.insert(latest)
        try context.save()

        let prefill = try #require(QuickLogService.feedPrefill(for: room))
        #expect(prefill.kind == .water)
        #expect(prefill.volumeLiters == 2.5)
        #expect(prefill.phIn == 6.2)
        #expect(prefill.ecIn == 1.6)
        #expect(prefill.date == latest.date)
    }

    @Test func readingPrefillUsesTheLatestReading() throws {
        let context = try makeContext()
        let room = Room(name: "Tent")
        context.insert(room)

        let older = EnvironmentReading(date: Date().addingTimeInterval(-3600), temperatureC: 20, room: room)
        let latest = EnvironmentReading(
            date: Date(),
            temperatureC: 24.5,
            humidityPercent: 55,
            lightPPFD: 450,
            room: room
        )
        context.insert(older)
        context.insert(latest)
        try context.save()

        let prefill = try #require(QuickLogService.readingPrefill(for: room))
        #expect(prefill.temperatureC == 24.5)
        #expect(prefill.humidityPercent == 55)
        #expect(prefill.lightPPFD == 450)
    }

    @Test func stagePreviewCountsOnlyTheStagesTheRuleCounts() throws {
        let context = try makeContext()
        let room = Room(name: "Tent")
        context.insert(room)

        let veg = Plant(name: "Veg", stage: .veg, room: room)
        let flower = Plant(name: "Flower", stage: .flower, room: room)
        let clone = Plant(name: "Clone", stage: .clone, room: room)
        context.insert(veg)
        context.insert(flower)
        context.insert(clone)
        try context.save()

        let rule = testRule(plantLimit: 2)
        let plants = [veg, flower, clone]

        // A clone is not counted, so moving it into veg takes the count to 3.
        let crossing = QuickLogService.countPreview(
            plant: clone,
            to: .veg,
            plants: plants,
            rule: rule,
            warningThreshold: 0.8
        )
        #expect(crossing.countedBefore == 2)
        #expect(crossing.countedAfter == 3)
        #expect(crossing.isOverLimit)
        #expect(crossing.level == .over)

        // Moving a flowering plant to harvest lowers the count.
        let lowering = QuickLogService.countPreview(
            plant: flower,
            to: .harvest,
            plants: plants,
            rule: rule,
            warningThreshold: 0.8
        )
        #expect(lowering.countedBefore == 2)
        #expect(lowering.countedAfter == 1)
        #expect(!lowering.isOverLimit)

        // A clone moving to veg from flower is unchanged for a veg clone.
        let same = QuickLogService.countPreview(
            plant: veg,
            to: .flower,
            plants: plants,
            rule: rule,
            warningThreshold: 0.8
        )
        #expect(same.countedBefore == 2)
        #expect(same.countedAfter == 2)
        #expect(!same.isOverLimit)
    }

    @Test func aStageChangeWritesOneEventAndUpdatesHarvestDate() throws {
        let context = try makeContext()
        let room = Room(name: "Tent")
        context.insert(room)
        let plant = Plant(name: "One", stage: .flower, room: room)
        context.insert(plant)
        try context.save()

        _ = try QuickLogService.changeStage(plant: plant, to: .harvest, in: context)

        #expect(plant.stage == .harvest)
        #expect(plant.harvestedAt != nil)
        #expect(try context.fetchCount(FetchDescriptor<StageEvent>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Plant>()) == 1)
    }

    @Test func aStageChangeToTheSameStageIsRejected() throws {
        let context = try makeContext()
        let plant = Plant(name: "One", stage: .veg)
        context.insert(plant)
        try context.save()

        #expect(throws: QuickLogError.self) {
            try QuickLogService.changeStage(plant: plant, to: .veg, in: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<StageEvent>()) == 0)
    }

    @Test func savingEachActionWritesExactlyOneRecordAndRemembersTheContext() throws {
        let context = try makeContext()
        QuickLogPreferences.reset()
        defer { QuickLogPreferences.reset() }

        let room = Room(name: "Tent")
        context.insert(room)
        let plant = Plant(name: "One", stage: .veg, room: room)
        context.insert(plant)
        try context.save()

        _ = try QuickLogService.logFeed(
            room: room,
            kind: .water,
            volumeLiters: 2,
            phIn: nil,
            ecIn: nil,
            in: context
        )
        #expect(try context.fetchCount(FetchDescriptor<FeedEvent>()) == 1)
        #expect(QuickLogPreferences.roomName == "Tent")

        _ = try QuickLogService.logReading(
            room: room,
            temperatureC: 24,
            humidityPercent: 55,
            lightPPFD: nil,
            in: context
        )
        #expect(try context.fetchCount(FetchDescriptor<EnvironmentReading>()) == 1)

        _ = try QuickLogService.logNote(
            text: "Lower leaves pale",
            plant: plant,
            room: room,
            in: context
        )
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 1)
        #expect(QuickLogPreferences.plantName == "One")

        _ = try QuickLogService.changeStage(plant: plant, to: .flower, in: context)
        #expect(try context.fetchCount(FetchDescriptor<StageEvent>()) == 1)
        #expect(plant.stage == .flower)
    }

    @Test func anEmptyNoteIsRejected() throws {
        let context = try makeContext()
        let plant = Plant(name: "One", stage: .veg)
        context.insert(plant)
        try context.save()

        #expect(throws: QuickLogError.self) {
            try QuickLogService.logNote(text: "   ", plant: plant, room: nil, in: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 0)
    }

    @Test func destroyedPlantsStopCounting() throws {
        let context = try makeContext()
        let room = Room(name: "Tent")
        context.insert(room)
        let plant = Plant(name: "One", stage: .flower, room: room)
        plant.harvestDisposition = .destroyed
        context.insert(plant)
        try context.save()

        let preview = QuickLogService.countPreview(
            plant: plant,
            to: .flower,
            plants: [plant],
            rule: testRule(plantLimit: 2),
            warningThreshold: 0.8
        )
        #expect(preview.countedBefore == 0)
        #expect(preview.countedAfter == 0)
    }

    // MARK: Support

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func testRule(plantLimit: Int) -> JurisdictionRule {
        JurisdictionRule(
            stateCode: "TS",
            stateName: "Test",
            plantLimit: plantLimit,
            countedStages: [.veg, .flower],
            countsClones: false,
            countingNote: "Vegetative and flowering plants count.",
            summary: "Test rule",
            citation: "Test citation",
            sourceURL: ""
        )
    }
}
