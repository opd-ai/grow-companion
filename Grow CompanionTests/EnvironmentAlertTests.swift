//
//  EnvironmentAlertTests.swift
//  Grow CompanionTests
//
//  A sustained excursion fires only when the readings evidence one: close
//  enough together, long enough, and not reset by a return to range.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct EnvironmentAlertTests {
    private let target = 18.0...24.0

    @Test func aBriefSpikeIsNotSustained() throws {
        let context = try alertContext()
        let now = Date()
        let readings = [
            try reading(at: now, temperatureC: 30, in: context),
            try reading(at: now.addingTimeInterval(2 * 60), temperatureC: 31, in: context)
        ]

        let excursions = EnvironmentAlertService.excursions(
            in: readings,
            metric: .temperature,
            target: target,
            requiredMinutes: 10
        )

        #expect(excursions.isEmpty)
    }

    @Test func fifteenMinutesOutOfRangeIsSustained() throws {
        let context = try alertContext()
        let start = Date()
        let readings = [
            try reading(at: start, temperatureC: 28, in: context),
            try reading(at: start.addingTimeInterval(5 * 60), temperatureC: 29, in: context),
            try reading(at: start.addingTimeInterval(10 * 60), temperatureC: 30, in: context),
            try reading(at: start.addingTimeInterval(15 * 60), temperatureC: 31, in: context)
        ]

        let excursions = EnvironmentAlertService.excursions(
            in: readings,
            metric: .temperature,
            target: target,
            requiredMinutes: 10
        )

        let excursion = try #require(excursions.first)
        #expect(excursions.count == 1)
        #expect(excursion.lastedMinutes >= 15)
        #expect(excursion.value == 31)
        #expect(excursion.isAbove)
        #expect(excursion.startedAt == start)
    }

    @Test func aLongGapBreaksTheExcursion() throws {
        let context = try alertContext()
        let start = Date()
        let readings = [
            try reading(at: start, temperatureC: 30, in: context),
            try reading(at: start.addingTimeInterval(60), temperatureC: 30, in: context),
            // Two hours later: the record does not show the room stayed hot.
            try reading(at: start.addingTimeInterval(2 * 60 * 60), temperatureC: 30, in: context)
        ]

        let excursions = EnvironmentAlertService.excursions(
            in: readings,
            metric: .temperature,
            target: target,
            requiredMinutes: 10
        )

        #expect(excursions.isEmpty)
    }

    @Test func aReturnToRangeStartsANewExcursion() throws {
        let context = try alertContext()
        let start = Date()
        let readings = [
            try reading(at: start, temperatureC: 30, in: context),
            try reading(at: start.addingTimeInterval(15 * 60), temperatureC: 30, in: context),
            try reading(at: start.addingTimeInterval(20 * 60), temperatureC: 22, in: context),
            try reading(at: start.addingTimeInterval(30 * 60), temperatureC: 30, in: context),
            try reading(at: start.addingTimeInterval(45 * 60), temperatureC: 30, in: context)
        ]

        let excursions = EnvironmentAlertService.excursions(
            in: readings,
            metric: .temperature,
            target: target,
            requiredMinutes: 10
        )

        #expect(excursions.count == 2)
        #expect(excursions.last?.startedAt == start.addingTimeInterval(30 * 60))
    }

    @Test func humidityIsMeasuredSeparatelyFromTemperature() throws {
        let context = try alertContext()
        let start = Date()
        let readings = [
            EnvironmentReading(date: start, temperatureC: 22, humidityPercent: 80),
            EnvironmentReading(date: start.addingTimeInterval(15 * 60), temperatureC: 22, humidityPercent: 82)
        ]
        readings.forEach(context.insert)
        try context.save()

        let excursions = EnvironmentAlertService.excursions(
            in: readings,
            metric: .humidity,
            target: 50.0...65.0,
            requiredMinutes: 10
        )

        #expect(excursions.count == 1)
        #expect(excursions.first?.metric == .humidity)
        #expect(excursions.first?.isAbove == true)
    }

    @Test func theSuggestedActionMatchesTheDirection() {
        let high = EnvironmentAlertService.suggestedAction(for: .temperature, value: 30, target: target)
        let low = EnvironmentAlertService.suggestedAction(for: .temperature, value: 12, target: target)

        #expect(high.contains("above"))
        #expect(low.contains("below"))
        #expect(high != low)
    }

    // MARK: Support

    @discardableResult
    private func reading(
        at date: Date,
        temperatureC: Double,
        in context: ModelContext
    ) throws -> EnvironmentReading {
        let reading = EnvironmentReading(date: date, temperatureC: temperatureC)
        context.insert(reading)
        try context.save()
        return reading
    }

    private func alertContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}
