//
//  HarvestForecast.swift
//  Grow Companion
//
//  The calendar's forecast: a flowering plant's window and most likely finish
//  day, taken from the same figure its flower-week counter uses.
//

import Foundation
import SwiftData

struct HarvestForecast: Identifiable {
    let plant: Plant
    let now: Date
    let floweringStart: Date
    let expectedDays: Int
    let source: FloweringExpectation.Source
    let sampleCount: Int
    let mostLikelyDate: Date
    let windowStart: Date
    let windowEnd: Date
    let weeks: Int
    let currentWeek: Int
    let progress: Double

    var id: PersistentIdentifier { plant.persistentModelID }

    /// True once the whole forecast window, including its grace days, is behind us.
    var isOverrun: Bool {
        Calendar.current.startOfDay(for: now) > windowEnd
    }

    /// Days until the most likely finish day. Negative once it has passed.
    var daysRemaining: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: mostLikelyDate
        ).day ?? 0
    }

    var timingText: String {
        if daysRemaining > 0 {
            return "· \(Format.dayCount(daysRemaining))"
        }
        if daysRemaining == 0 {
            return "· today"
        }
        return "· \(Format.dayCount(abs(daysRemaining))) over"
    }

    var sourceText: String {
        switch source {
        case .observed:
            return String(localized: "From your observed flowering time")
        case .breeder:
            return String(localized: "From the breeder's figure")
        case .typical:
            return String(localized: "From the usual flowering time")
        }
    }
}

enum HarvestCalendar {
    /// The window is the expected finish day plus or minus this many days.
    static let windowPaddingDays = 7

    static func forecasts(for plants: [Plant], now: Date = Date()) -> [HarvestForecast] {
        plants
            .compactMap { forecast(for: $0, now: now) }
            .sorted { $0.mostLikelyDate < $1.mostLikelyDate }
    }

    /// A forecast only exists for a plant that is flowering right now. It is
    /// rebuilt from the plant's current stage and history every time it is
    /// asked for, so a stage change updates it immediately.
    static func forecast(for plant: Plant, now: Date = Date()) -> HarvestForecast? {
        guard plant.stage == .flower else { return nil }

        let calendar = Calendar.current
        let expectation = StrainInsights.expectation(for: plant)
        let start = calendar.startOfDay(for: plant.stageStartedAt)

        guard let likely = calendar.date(byAdding: .day, value: expectation.days, to: start),
              let windowStart = calendar.date(byAdding: .day, value: -windowPaddingDays, to: likely),
              let windowEnd = calendar.date(byAdding: .day, value: windowPaddingDays, to: likely)
        else { return nil }

        let progress = min(1, max(0, Double(plant.daysInStage) / Double(max(1, expectation.days))))

        return HarvestForecast(
            plant: plant,
            now: now,
            floweringStart: start,
            expectedDays: expectation.days,
            source: expectation.source,
            sampleCount: expectation.sampleCount,
            mostLikelyDate: likely,
            windowStart: windowStart,
            windowEnd: windowEnd,
            weeks: expectation.weeks,
            currentWeek: StrainInsights.currentFlowerWeek(for: plant),
            progress: progress
        )
    }
}
