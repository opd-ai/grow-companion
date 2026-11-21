//
//  ScreenPlanner.swift
//  Grow Companion
//
//  The screen plan's whole lifecycle: opening the one plan a room keeps,
//  placing and emptying a square, changing the grid size and clearing it. Every
//  calculation is pure and the writes are small, so a grid the grower built by
//  hand is never rebuilt behind their back.
//

import Foundation
import SwiftData

/// One square as the planner draws it, including the empty ones, so the grid is
/// always the full size the plan declares.
struct ScreenGridCell: Identifiable, Equatable {
    let column: Int
    let row: Int
    let plantName: String?
    let plantID: PersistentIdentifier?
    let filledAt: Date?

    var id: String { "\(column)-\(row)" }

    var isFilled: Bool { plantID != nil }
}

struct ScreenPlanStats: Equatable {
    let columns: Int
    let rows: Int
    let filled: Int

    var total: Int { max(0, columns * rows) }
    var emptyCount: Int { max(0, total - filled) }
    var fraction: Double { total > 0 ? Double(filled) / Double(total) : 0 }
    var percentText: String { Format.percent(fraction) }

    /// `4 × 4`
    var sizeText: String { "\(columns) × \(rows)" }
}

struct ScreenPlantCount: Identifiable, Equatable {
    let plantID: PersistentIdentifier
    let name: String
    let count: Int

    var id: PersistentIdentifier { plantID }
}

enum ScreenPlannerError: LocalizedError {
    case invalidSize
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSize:
            return String(localized: "A screen is between \(ScreenPlanner.Limits.minimum) and \(ScreenPlanner.Limits.maximum) squares wide and deep.")
        case .saveFailed(let detail):
            return String(localized: "The screen was not saved: \(detail)")
        }
    }
}

enum ScreenPlanner {
    enum Limits {
        static let minimum = 2
        static let maximum = 12
        static let defaultColumns = 6
        static let defaultRows = 6
    }

    static func clamped(_ value: Int) -> Int {
        min(max(value, Limits.minimum), Limits.maximum)
    }

    // MARK: - Opening the plan

    static func plan(for room: Room) -> ScreenPlan? { room.screenPlan }

    /// The room's plan, created with an empty grid the first time it is opened,
    /// and repaired to match its declared size afterwards.
    @discardableResult
    static func ensurePlan(
        for room: Room,
        in context: ModelContext,
        now: Date = Date()
    ) throws -> ScreenPlan {
        if let existing = room.screenPlan {
            try reconcile(existing, in: context, now: now)
            return existing
        }

        let created = ScreenPlan(
            columns: Limits.defaultColumns,
            rows: Limits.defaultRows,
            startedAt: now,
            room: room
        )
        context.insert(created)
        try reconcile(created, in: context, now: now)
        return created
    }

    // MARK: - Reading the grid

    /// Every square of the plan, full size, top-left first. Squares outside the
    /// declared size are ignored rather than drawn.
    static func cells(of plan: ScreenPlan) -> [ScreenGridCell] {
        var byCoordinate: [String: ScreenCell] = [:]
        for cell in plan.cells where isInside(plan, column: cell.column, row: cell.row) {
            let key = coordinateKey(column: cell.column, row: cell.row)
            if byCoordinate[key] == nil { byCoordinate[key] = cell }
        }

        var result: [ScreenGridCell] = []
        for row in 0..<max(0, plan.rows) {
            for column in 0..<max(0, plan.columns) {
                let cell = byCoordinate[coordinateKey(column: column, row: row)]
                result.append(
                    ScreenGridCell(
                        column: column,
                        row: row,
                        plantName: cell?.plant?.displayName,
                        plantID: cell?.plant?.persistentModelID,
                        filledAt: cell?.filledAt
                    )
                )
            }
        }
        return result
    }

    static func stats(of plan: ScreenPlan) -> ScreenPlanStats {
        let filled = plan.cells.filter {
            isInside(plan, column: $0.column, row: $0.row) && $0.isFilled
        }.count
        return ScreenPlanStats(
            columns: max(0, plan.columns),
            rows: max(0, plan.rows),
            filled: filled
        )
    }

    /// How many squares each plant holds, largest first.
    static func plantCounts(of plan: ScreenPlan) -> [ScreenPlantCount] {
        var found: [PersistentIdentifier: (name: String, count: Int)] = [:]
        for cell in plan.cells {
            guard cell.isFilled,
                  isInside(plan, column: cell.column, row: cell.row),
                  let plant = cell.plant else { continue }
            let id = plant.persistentModelID
            let existing = found[id]
            found[id] = (existing?.name ?? plant.displayName, (existing?.count ?? 0) + 1)
        }

        return found
            .map { ScreenPlantCount(plantID: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted { ($0.count, $0.name) > ($1.count, $1.name) }
    }

    /// The line the room dashboard shows: `12 of 36 positions filled · 33%`.
    static func summary(of plan: ScreenPlan) -> String {
        let stats = stats(of: plan)
        return String(localized: "\(stats.filled) of \(stats.total) positions filled · \(stats.percentText)")
    }

    static func cell(column: Int, row: Int, in plan: ScreenPlan) -> ScreenCell? {
        plan.cells.first { $0.column == column && $0.row == row }
    }

    // MARK: - Writing the grid

    /// Places the plant's branch in a square, or empties the square when the
    /// same plant is already there. Another plant's branch is replaced.
    static func toggle(
        column: Int,
        row: Int,
        plant: Plant,
        plan: ScreenPlan,
        in context: ModelContext,
        now: Date = Date()
    ) throws {
        guard isInside(plan, column: column, row: row) else {
            throw ScreenPlannerError.invalidSize
        }

        let target = cell(column: column, row: row, in: plan)
            ?? makeCell(column: column, row: row, plan: plan, in: context)

        if target.plant?.persistentModelID == plant.persistentModelID {
            target.plant = nil
            target.filledAt = nil
        } else {
            target.plant = plant
            target.filledAt = now
        }

        plan.updatedAt = now
        try save(in: context)
    }

    static func clear(_ plan: ScreenPlan, in context: ModelContext, now: Date = Date()) throws {
        for cell in plan.cells where cell.isFilled {
            cell.plant = nil
            cell.filledAt = nil
        }
        plan.updatedAt = now
        try save(in: context)
    }

    /// How many placed branches a smaller grid would remove, so the screen can
    /// ask before it takes them.
    static func filledCountLost(resizing plan: ScreenPlan, columns: Int, rows: Int) -> Int {
        let newColumns = clamped(columns)
        let newRows = clamped(rows)
        return plan.cells.filter {
            $0.isFilled && ($0.column >= newColumns || $0.row >= newRows)
        }.count
    }

    static func resize(
        _ plan: ScreenPlan,
        columns: Int,
        rows: Int,
        in context: ModelContext,
        now: Date = Date()
    ) throws {
        plan.columns = clamped(columns)
        plan.rows = clamped(rows)
        plan.updatedAt = now
        try reconcile(plan, in: context, now: now)
    }

    /// Empties the positions a plant holds on any screen without deleting the
    /// squares, called before the plant itself is removed.
    static func clearPositions(of plant: Plant) {
        for cell in plant.screenCells where cell.isFilled {
            cell.plant = nil
            cell.filledAt = nil
        }
    }

    // MARK: - Geometry

    static func isInside(_ plan: ScreenPlan, column: Int, row: Int) -> Bool {
        column >= 0 && row >= 0 && column < plan.columns && row < plan.rows
    }

    private static func coordinateKey(column: Int, row: Int) -> String {
        "\(column)-\(row)"
    }

    private static func makeCell(
        column: Int,
        row: Int,
        plan: ScreenPlan,
        in context: ModelContext
    ) -> ScreenCell {
        let cell = ScreenCell(column: column, row: row, plan: plan)
        context.insert(cell)
        return cell
    }

    /// Adds the squares a larger grid needs and removes the ones a smaller grid
    /// no longer has.
    @discardableResult
    private static func reconcile(
        _ plan: ScreenPlan,
        in context: ModelContext,
        now: Date
    ) throws -> Int {
        var removedFilled = 0
        var present: Set<String> = []

        for cell in plan.cells {
            guard isInside(plan, column: cell.column, row: cell.row) else {
                if cell.isFilled { removedFilled += 1 }
                context.delete(cell)
                continue
            }
            present.insert(coordinateKey(column: cell.column, row: cell.row))
        }

        for row in 0..<max(0, plan.rows) {
            for column in 0..<max(0, plan.columns) {
                guard !present.contains(coordinateKey(column: column, row: row)) else { continue }
                let cell = ScreenCell(column: column, row: row, plan: plan)
                context.insert(cell)
            }
        }

        plan.updatedAt = now
        try save(in: context)
        return removedFilled
    }

    private static func save(in context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw ScreenPlannerError.saveFailed(error.localizedDescription)
        }
    }
}
