//
//  ScreenPlannerTests.swift
//  Grow CompanionTests
//
//  The screen planner: one plan per room, the grid it declares, the squares it
//  places and empties, the branches it asks about before a smaller grid removes
//  them, and its place in every data control.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct ScreenPlannerTests {
    private func screenContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func makeRoom(in context: ModelContext, plants: Int = 2) throws -> Room {
        let room = Room(name: "Tent")
        context.insert(room)
        for index in 0..<plants {
            let plant = Plant(name: "Plant \(index + 1)", room: room)
            context.insert(plant)
        }
        try context.save()
        return room
    }

    @Test func aNewPlanIsAFullGridOfEmptySquares() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)

        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)

        #expect(plan.columns == ScreenPlanner.Limits.defaultColumns)
        #expect(plan.rows == ScreenPlanner.Limits.defaultRows)
        #expect(plan.cells.count == plan.columns * plan.rows)
        #expect(ScreenPlanner.stats(of: plan).filled == 0)
        #expect(try context.fetchCount(FetchDescriptor<ScreenCell>()) == plan.columns * plan.rows)
        #expect(room.screenPlan?.persistentModelID == plan.persistentModelID)
    }

    @Test func aRoomKeepsOnePlan() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)

        let first = try ScreenPlanner.ensurePlan(for: room, in: context)
        let second = try ScreenPlanner.ensurePlan(for: room, in: context)

        #expect(first.persistentModelID == second.persistentModelID)
        #expect(try context.fetchCount(FetchDescriptor<ScreenPlan>()) == 1)
    }

    @Test func placingABranchFillsItsSquare() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)
        let plant = try #require(room.plants.first)
        let stamp = Date(timeIntervalSince1970: 1_000_000)

        try ScreenPlanner.toggle(column: 1, row: 2, plant: plant, plan: plan, in: context, now: stamp)

        let cell = try #require(ScreenPlanner.cell(column: 1, row: 2, in: plan))
        #expect(cell.plant?.persistentModelID == plant.persistentModelID)
        #expect(cell.filledAt == stamp)
        #expect(ScreenPlanner.stats(of: plan).filled == 1)
        #expect(plan.cells.count == plan.columns * plan.rows)
    }

    @Test func tappingTheSamePlantEmptiesTheSquare() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)
        let plant = try #require(room.plants.first)

        try ScreenPlanner.toggle(column: 0, row: 0, plant: plant, plan: plan, in: context)
        try ScreenPlanner.toggle(column: 0, row: 0, plant: plant, plan: plan, in: context)

        let cell = try #require(ScreenPlanner.cell(column: 0, row: 0, in: plan))
        #expect(cell.plant == nil)
        #expect(cell.filledAt == nil)
        #expect(ScreenPlanner.stats(of: plan).filled == 0)
    }

    @Test func anotherPlantTakesTheSquare() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)
        let first = try #require(room.plants.first)
        let second = try #require(room.plants.last)

        try ScreenPlanner.toggle(column: 3, row: 3, plant: first, plan: plan, in: context)
        try ScreenPlanner.toggle(column: 3, row: 3, plant: second, plan: plan, in: context)

        let cell = try #require(ScreenPlanner.cell(column: 3, row: 3, in: plan))
        #expect(cell.plant?.persistentModelID == second.persistentModelID)
        #expect(ScreenPlanner.stats(of: plan).filled == 1)
    }

    @Test func theCountsFollowThePlacedBranches() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)
        let first = try #require(room.plants.first)
        let second = try #require(room.plants.last)

        try ScreenPlanner.toggle(column: 0, row: 0, plant: first, plan: plan, in: context)
        try ScreenPlanner.toggle(column: 1, row: 0, plant: first, plan: plan, in: context)
        try ScreenPlanner.toggle(column: 2, row: 0, plant: second, plan: plan, in: context)

        let counts = ScreenPlanner.plantCounts(of: plan)
        #expect(counts.count == 2)
        #expect(counts.first?.plantID == first.persistentModelID)
        #expect(counts.first?.count == 2)
        #expect(counts.last?.count == 1)
    }

    @Test func theGridReportsEverySquareTopLeftFirst() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)

        let cells = ScreenPlanner.cells(of: plan)

        #expect(cells.count == plan.columns * plan.rows)
        #expect(cells.first?.column == 0)
        #expect(cells.first?.row == 0)
        #expect(cells.last?.column == plan.columns - 1)
        #expect(cells.last?.row == plan.rows - 1)
        #expect(cells.allSatisfy { !$0.isFilled })
    }

    @Test func aSmallerGridAsksBeforeItRemovesPlacedBranches() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)
        let plant = try #require(room.plants.first)

        try ScreenPlanner.toggle(column: 5, row: 5, plant: plant, plan: plan, in: context)
        try ScreenPlanner.toggle(column: 0, row: 0, plant: plant, plan: plan, in: context)

        #expect(ScreenPlanner.filledCountLost(resizing: plan, columns: 4, rows: 4) == 1)

        try ScreenPlanner.resize(plan, columns: 4, rows: 4, in: context)

        #expect(plan.columns == 4)
        #expect(plan.rows == 4)
        #expect(plan.cells.count == 16)
        #expect(ScreenPlanner.stats(of: plan).filled == 1)
        #expect(ScreenPlanner.cell(column: 0, row: 0, in: plan)?.isFilled == true)
        #expect(ScreenPlanner.cell(column: 5, row: 5, in: plan) == nil)
    }

    @Test func aLargerGridAddsEmptySquares() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)

        try ScreenPlanner.resize(plan, columns: 8, rows: 7, in: context)

        #expect(plan.cells.count == 56)
        #expect(ScreenPlanner.cells(of: plan).count == 56)
        #expect(plan.filledCount == 0)
    }

    @Test func theSizeStaysWithinItsLimits() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)

        try ScreenPlanner.resize(plan, columns: 99, rows: 0, in: context)

        #expect(plan.columns == ScreenPlanner.Limits.maximum)
        #expect(plan.rows == ScreenPlanner.Limits.minimum)
        #expect(ScreenPlanner.stats(of: plan).total == ScreenPlanner.Limits.maximum * ScreenPlanner.Limits.minimum)
    }

    @Test func clearingEmptiesEveryPositionAndKeepsTheSize() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)
        let plant = try #require(room.plants.first)

        try ScreenPlanner.toggle(column: 0, row: 0, plant: plant, plan: plan, in: context)
        try ScreenPlanner.toggle(column: 4, row: 4, plant: plant, plan: plan, in: context)
        #expect(ScreenPlanner.stats(of: plan).filled == 2)

        try ScreenPlanner.clear(plan, in: context)

        #expect(ScreenPlanner.stats(of: plan).filled == 0)
        #expect(plan.cells.count == plan.columns * plan.rows)
        #expect(ScreenPlanner.cell(column: 0, row: 0, in: plan)?.filledAt == nil)
    }

    @Test func removingAPlantEmptiesItsPositionsAndKeepsTheGrid() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)
        let plant = try #require(room.plants.first)

        try ScreenPlanner.toggle(column: 2, row: 2, plant: plant, plan: plan, in: context)

        try PlantRemovalService.delete(plant, in: context)

        #expect(ScreenPlanner.stats(of: plan).filled == 0)
        #expect(plan.cells.count == plan.columns * plan.rows)
        #expect(ScreenPlanner.plantCounts(of: plan).isEmpty)
    }

    @Test func thePlanIsInEveryDataControl() {
        let names = DataInventory.modelNames

        #expect(names.contains("ScreenPlan"))
        #expect(names.contains("ScreenCell"))
        #expect(DataInventory.probes.map(\.name).contains("ScreenPlan"))
        #expect(ExportService.exportedModelNames.contains("ScreenPlan"))
        #expect(ExportService.exportedModelNames.contains("ScreenCell"))
        #expect(DataInventory.label(for: "ScreenPlan") != "ScreenPlan")
        #expect(DataInventory.label(for: "ScreenCell") != "ScreenCell")
    }

    @Test func thePlanTravelsThroughTheBackupDocument() throws {
        let context = try screenContext()
        let room = try makeRoom(in: context)
        let plan = try ScreenPlanner.ensurePlan(for: room, in: context)
        let plant = try #require(room.plants.first)

        try ScreenPlanner.toggle(column: 1, row: 0, plant: plant, plan: plan, in: context)

        let snapshot = ExportSnapshot(
            rooms: [room],
            plants: [plant],
            screenPlans: [plan],
            counts: DataInventory.counts(in: context)
        )
        let data = try ExportService.buildBackup(
            snapshot: snapshot,
            includeJournal: false,
            includePhotos: false,
            password: "correct-horse-battery"
        )

        let root = try ExportService.decodeBackup(data, password: "correct-horse-battery")
        let section = try #require(root["screenPlans"] as? [[String: Any]])
        let stored = try #require(section.first)

        #expect(section.count == 1)
        #expect(stored["room"] as? String == "Tent")
        #expect(stored["columns"] as? Int == plan.columns)
        #expect(stored["rows"] as? Int == plan.rows)

        let cells = try #require(stored["cells"] as? [[String: Any]])
        let placed = try #require(cells.first { $0["plant"] as? String == "Plant 1" })

        #expect(placed["column"] as? Int == 1)
        #expect(placed["row"] as? Int == 0)

        try BackupService.validate(root)
    }
}
