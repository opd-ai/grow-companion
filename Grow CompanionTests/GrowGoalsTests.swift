//
//  GrowGoalsTests.swift
//  Grow CompanionTests
//
//  The cycle goals: measurement from the records, the missing-data rule, the
//  single stored record, and their place in export, backup and delete.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct GrowGoalMeasurementTests {
    @Test func dryYieldIsMissingUntilAPlantHasADryWeight() throws {
        let context = try goalContext()
        let plant = Plant(name: "One")
        context.insert(plant)
        try context.save()

        #expect(GrowGoalService.dryYieldGrams(from: [plant]) == nil)

        plant.dryWeightGrams = 120
        try context.save()

        #expect(GrowGoalService.dryYieldGrams(from: [plant]) == 120)
    }

    @Test func dryYieldAddsEveryRecordedWeight() throws {
        let context = try goalContext()
        let first = Plant(name: "One")
        let second = Plant(name: "Two")
        context.insert(first)
        context.insert(second)
        first.dryWeightGrams = 100
        second.dryWeightGrams = 150
        try context.save()

        #expect(GrowGoalService.dryYieldGrams(from: [first, second]) == 250)
    }

    @Test func floweringTimeIgnoresAPlantThatIsStillFlowering() throws {
        let context = try goalContext()
        let calendar = Calendar.current
        let now = Date()

        let running = Plant(name: "Running", stage: .flower)
        context.insert(running)
        context.insert(
            StageEvent(
                stage: .flower,
                date: calendar.date(byAdding: .day, value: -40, to: now) ?? now,
                plant: running
            )
        )
        try context.save()

        #expect(GrowGoalService.floweringDays(for: running) == nil)
        #expect(GrowGoalService.averageFloweringWeeks(from: [running]) == nil)
    }

    @Test func floweringTimeAveragesThePlantsThatFinished() throws {
        let context = try goalContext()
        let calendar = Calendar.current
        let now = Date()

        let plant = Plant(name: "Finished", stage: .harvest)
        context.insert(plant)
        context.insert(
            StageEvent(
                stage: .flower,
                date: calendar.date(byAdding: .day, value: -70, to: now) ?? now,
                plant: plant
            )
        )
        context.insert(
            StageEvent(
                stage: .harvest,
                date: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                plant: plant
            )
        )
        try context.save()

        #expect(GrowGoalService.floweringDays(for: plant) == 63)

        let weeks = try #require(GrowGoalService.averageFloweringWeeks(from: [plant]))
        #expect(abs(weeks - 9) < 0.01)
    }

    @Test func loggingCompletenessCountsTheDaysWithRecords() throws {
        let context = try goalContext()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let plantedAt = calendar.date(byAdding: .day, value: -9, to: today) ?? today

        let room = Room(name: "Tent")
        context.insert(room)

        let plant = Plant(name: "One", plantedAt: plantedAt, room: room)
        context.insert(plant)
        let entry = JournalEntry(kind: .note, text: "Two today", plant: plant)
        context.insert(entry)
        context.insert(EnvironmentReading(date: Date(), temperatureC: 24, room: room))
        try context.save()

        let sources = GrowGoalSources(plants: [plant], rooms: [room], journal: [entry])

        // Ten days in the window, two with a record, so twenty percent.
        let completeness = try #require(GrowGoalService.loggingCompleteness(from: sources))
        #expect(abs(completeness - 20) < 0.5)
    }

    @Test func loggingCompletenessIsMissingWithNothingToMeasure() throws {
        let sources = GrowGoalSources()
        #expect(GrowGoalService.loggingCompleteness(from: sources) == nil)
    }
}

@Suite(.serialized)
struct GrowGoalStorageTests {
    @Test func savingRejectsATargetOfZeroAndChangesNothing() throws {
        let context = try goalContext()

        #expect(throws: GrowGoalError.self) {
            try GrowGoalService.save(
                dryYieldTargetGrams: 0,
                floweringWeeksTarget: nil,
                loggingCompletenessTargetPercent: nil,
                existing: nil,
                in: context
            )
        }

        #expect(DataInventory.counts(in: context)["GrowGoal"] == 0)
    }

    @Test func savingNoTargetsRemovesTheRecord() throws {
        let context = try goalContext()

        let created = try GrowGoalService.save(
            dryYieldTargetGrams: 250,
            floweringWeeksTarget: 9,
            loggingCompletenessTargetPercent: 80,
            existing: nil,
            in: context
        )
        #expect(created != nil)
        #expect(DataInventory.counts(in: context)["GrowGoal"] == 1)

        let removed = try GrowGoalService.save(
            dryYieldTargetGrams: nil,
            floweringWeeksTarget: nil,
            loggingCompletenessTargetPercent: nil,
            existing: created,
            in: context
        )
        #expect(removed == nil)
        #expect(DataInventory.counts(in: context)["GrowGoal"] == 0)
    }

    @Test func editingKeepsOneRecord() throws {
        let context = try goalContext()

        let first = try GrowGoalService.save(
            dryYieldTargetGrams: 250,
            floweringWeeksTarget: nil,
            loggingCompletenessTargetPercent: nil,
            existing: nil,
            in: context
        )

        let second = try GrowGoalService.save(
            dryYieldTargetGrams: nil,
            floweringWeeksTarget: 10,
            loggingCompletenessTargetPercent: 75,
            existing: first,
            in: context
        )

        #expect(DataInventory.counts(in: context)["GrowGoal"] == 1)
        #expect(second?.dryYieldTargetGrams == nil)
        #expect(second?.floweringWeeksTarget == 10)
        #expect(GrowGoalService.current(from: [try #require(second)]) != nil)
    }

    @Test func progressReportsMissingDataInsteadOfZeroProgress() throws {
        let context = try goalContext()
        let goal = GrowGoal(dryYieldTargetGrams: 250)
        context.insert(goal)
        try context.save()

        let items = GrowGoalService.progress(goal: goal, sources: GrowGoalSources(), unit: .metric)
        let item = try #require(items.first)

        #expect(item.kind == .dryYield)
        #expect(item.measured == nil)
        #expect(item.fraction == nil)
        #expect(item.statusText.contains("Nothing to measure yet"))
    }

    @Test func progressIsAValueAgainstTheTarget() throws {
        let context = try goalContext()
        let plant = Plant(name: "One")
        context.insert(plant)
        plant.dryWeightGrams = 125
        try context.save()

        let goal = GrowGoal(dryYieldTargetGrams: 250)
        context.insert(goal)
        try context.save()

        let items = GrowGoalService.progress(
            goal: goal,
            sources: GrowGoalSources(plants: [plant]),
            unit: .metric
        )
        let item = try #require(items.first)

        #expect(item.measured == 125)
        #expect(item.fraction == 0.5)
        #expect(item.statusText.contains("125 g"))
        #expect(item.statusText.contains("target 250 g"))
    }
}

@Suite(.serialized)
struct GrowGoalDataControlTests {
    @Test func cycleGoalsAreInTheSchemaAndMigration() {
        #expect(DataInventory.modelNames.contains("GrowGoal"))
        #expect(DataInventory.label(for: "GrowGoal") != "GrowGoal")
        #expect(CultivationMigrationPlan.stages.count == 3)
        #expect(
            CultivationSchemaV3.models.contains { String(describing: $0) == "GrowGoal" }
        )
    }

    @Test func cyclesGoalsAreExportedAndBackedUp() throws {
        let context = try goalContext()
        let goal = GrowGoal(
            dryYieldTargetGrams: 250,
            floweringWeeksTarget: 9,
            loggingCompletenessTargetPercent: 80
        )
        context.insert(goal)
        try context.save()

        let counts = DataInventory.counts(in: context)
        #expect(counts["GrowGoal"] == 1)

        let snapshot = ExportSnapshot(goals: [goal], counts: counts)

        let json = try ExportService.jsonData(snapshot: snapshot, options: ExportOptions())
        let root = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        let goals = try #require(root["goals"] as? [[String: Any]])

        #expect(goals.count == 1)
        #expect(goals.first?["dryYieldTargetGrams"] as? Double == 250)
        #expect(goals.first?["floweringWeeksTarget"] as? Int == 9)
        #expect(goals.first?["loggingCompletenessTargetPercent"] as? Int == 80)

        let manifest = try #require(root["manifest"] as? [String: Any])
        #expect((manifest["counts"] as? [String: Any])?["GrowGoal"] as? Int == 1)

        let backup = try ExportService.buildBackup(
            snapshot: snapshot,
            includeJournal: false,
            includePhotos: false,
            password: "correct-horse-battery"
        )
        let decoded = try ExportService.decodeBackup(backup, password: "correct-horse-battery")
        try BackupService.validate(decoded)
    }

    @Test func deleteAllRemovesCycleGoals() throws {
        let context = try goalContext()
        context.insert(GrowGoal(dryYieldTargetGrams: 300))
        try context.save()

        let remaining = try DataInventory.deleteAll(in: context)
        #expect(remaining["GrowGoal"] == 0)
        #expect(DataInventory.total(of: remaining) == 0)
    }
}

private func goalContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: DataInventory.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    return ModelContext(container)
}
