//
//  ScreenPlan.swift
//  Grow Companion
//
//  A training screen (a SCROG net) for one room: the grid of squares the grower
//  fills with the branches tucked under it. The plan is a map the grower keeps.
//  Nothing in it is measured or inferred, and it never leaves the device.
//

import Foundation
import SwiftData

@Model
final class ScreenPlan {
    var name: String = ""
    var columns: Int = ScreenPlanner.Limits.defaultColumns
    var rows: Int = ScreenPlanner.Limits.defaultRows
    var note: String = ""
    var startedAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var room: Room?

    @Relationship(deleteRule: .cascade, inverse: \ScreenCell.plan)
    var cells: [ScreenCell] = []

    init(
        name: String = "",
        columns: Int = ScreenPlanner.Limits.defaultColumns,
        rows: Int = ScreenPlanner.Limits.defaultRows,
        note: String = "",
        startedAt: Date = Date(),
        room: Room? = nil
    ) {
        self.name = name
        self.columns = columns
        self.rows = rows
        self.note = note
        self.startedAt = startedAt
        self.createdAt = startedAt
        self.updatedAt = startedAt
        self.room = room
    }

    /// Top-left first, reading along each row.
    var sortedCells: [ScreenCell] {
        cells.sorted { ($0.row, $0.column) < ($1.row, $1.column) }
    }

    var squareCount: Int { max(0, columns * rows) }

    var filledCells: [ScreenCell] { cells.filter(\.isFilled) }

    var filledCount: Int { filledCells.count }
}

/// One square of the net: a column, a row, and the plant whose branch sits
/// there. `filledAt` records when the branch was placed, so the grower can see
/// how the canopy filled over time.
@Model
final class ScreenCell {
    var column: Int = 0
    var row: Int = 0
    var filledAt: Date?
    var plant: Plant?
    var plan: ScreenPlan?

    init(
        column: Int,
        row: Int,
        plant: Plant? = nil,
        filledAt: Date? = nil,
        plan: ScreenPlan? = nil
    ) {
        self.column = column
        self.row = row
        self.plant = plant
        self.filledAt = filledAt
        self.plan = plan
    }

    var isFilled: Bool { plant != nil }
}
