//
//  FeedScheduleEngine.swift
//  Grow Companion
//
//  Week counting from a room's start date, the week's targets, and the copy
//  made when a schedule is duplicated for the next run.
//

import Foundation
import SwiftData

enum FeedScheduleEngine {
    /// The week a room is in today, counting week 1 from the start date.
    /// Nil when the schedule has not started, has finished, or is not applied.
    static func currentWeek(startDate: Date?, weekCount: Int, now: Date = Date()) -> Int? {
        guard let startDate, weekCount > 0 else { return nil }
        guard startDate <= now else { return nil }

        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        let week = days / 7 + 1
        guard week <= weekCount else { return nil }
        return week
    }

    static func isPending(startDate: Date?, now: Date = Date()) -> Bool {
        guard let startDate else { return false }
        return startDate > now
    }

    static func isFinished(startDate: Date?, weekCount: Int, now: Date = Date()) -> Bool {
        guard let startDate, startDate <= now, weekCount > 0 else { return false }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return days / 7 + 1 > weekCount
    }

    /// A copy with every week and product, ready to tweak for the next run.
    static func duplicate(_ schedule: FeedSchedule, context: ModelContext) -> FeedSchedule {
        let copy = FeedSchedule(
            name: "\(schedule.displayName) copy",
            weekCount: schedule.weekCount
        )
        context.insert(copy)

        for week in schedule.sortedWeeks {
            let newWeek = FeedWeek(
                weekNumber: week.weekNumber,
                targetPH: week.targetPH,
                targetEC: week.targetEC
            )
            context.insert(newWeek)
            newWeek.schedule = copy

            for (index, product) in week.sortedProducts.enumerated() {
                let newProduct = FeedProduct(
                    name: product.name,
                    doseMLPerLiter: product.doseMLPerLiter,
                    sortIndex: index
                )
                context.insert(newProduct)
                newProduct.week = newWeek
            }
        }

        try? context.save()
        return copy
    }

    /// "1.5 ml/L", without trailing zeros.
    static func doseText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(localized: "\(String(format: "%g", value)) ml/L")
    }

    static func statusText(
        schedule: FeedSchedule,
        room: Room?,
        now: Date = Date()
    ) -> String? {
        guard let room, room.feedSchedule?.persistentModelID == schedule.persistentModelID else {
            return nil
        }

        if isPending(startDate: room.feedScheduleStartDate, now: now) {
            let date = room.feedScheduleStartDate.map(Format.shortDate) ?? "soon"
            return String(localized: "Starts \(date)")
        }

        if let week = currentWeek(
            startDate: room.feedScheduleStartDate,
            weekCount: schedule.weekCount,
            now: now
        ) {
            return String(localized: "Week \(week) of \(schedule.weekCount)")
        }

        return String(localized: "All \(schedule.weekCount) weeks complete")
    }
}
