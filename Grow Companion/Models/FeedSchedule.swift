//
//  FeedSchedule.swift
//  Grow Companion
//
//  A reusable week-by-week feeding plan: a name, a week count, and for each
//  week the products, doses per litre and target pH and EC.
//

import Foundation
import SwiftData

@Model
final class FeedSchedule {
    var name: String = ""
    var weekCount: Int = 8
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \FeedWeek.schedule)
    var weeks: [FeedWeek] = []

    @Relationship(deleteRule: .nullify, inverse: \Room.feedSchedule)
    var appliedRooms: [Room] = []

    init(name: String = "", weekCount: Int = 8, createdAt: Date = Date()) {
        self.name = name
        self.weekCount = weekCount
        self.createdAt = createdAt
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed schedule" : trimmed
    }

    var sortedWeeks: [FeedWeek] {
        weeks.sorted { $0.weekNumber < $1.weekNumber }
    }

    func week(_ number: Int) -> FeedWeek? {
        weeks.first { $0.weekNumber == number }
    }

    var sortedAppliedRooms: [Room] {
        appliedRooms.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var appliedNames: String {
        sortedAppliedRooms.map(\.name).joined(separator: ", ")
    }

    var isApplied: Bool { !appliedRooms.isEmpty }
}

@Model
final class FeedWeek {
    var weekNumber: Int = 1
    var targetPH: Double?
    var targetEC: Double?
    var schedule: FeedSchedule?

    @Relationship(deleteRule: .cascade, inverse: \FeedProduct.week)
    var products: [FeedProduct] = []

    init(
        weekNumber: Int = 1,
        targetPH: Double? = nil,
        targetEC: Double? = nil,
        schedule: FeedSchedule? = nil
    ) {
        self.weekNumber = weekNumber
        self.targetPH = targetPH
        self.targetEC = targetEC
        self.schedule = schedule
    }

    var sortedProducts: [FeedProduct] {
        products.sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    }
}

@Model
final class FeedProduct {
    var name: String = ""
    var doseMLPerLiter: Double?
    var sortIndex: Int = 0
    var week: FeedWeek?

    init(name: String = "", doseMLPerLiter: Double? = nil, sortIndex: Int = 0, week: FeedWeek? = nil) {
        self.name = name
        self.doseMLPerLiter = doseMLPerLiter
        self.sortIndex = sortIndex
        self.week = week
    }
}
