//
//  EquipmentServiceTests.swift
//  Grow CompanionTests
//
//  A service record and the "last serviced" date stay consistent with each
//  other: a backfilled service never rewinds the schedule, a corrected date
//  moves it, and removing a record leaves the date following the history that
//  is still there.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct EquipmentServiceTests {
    @Test func loggingAServiceMovesTheScheduleForward() throws {
        let context = try equipmentContext()
        let calendar = Calendar.current
        let now = Date()
        let previous = calendar.date(byAdding: .day, value: -40, to: now) ?? now

        let item = Equipment(name: "Extractor fan", serviceIntervalDays: 30, lastServicedAt: previous)
        context.insert(item)
        try context.save()

        let record = try EquipmentService.add(date: now, note: "Cleaned the filter", to: item, in: context)

        #expect(item.lastServicedAt == now)
        #expect(record.note == "Cleaned the filter")
        #expect(try context.fetchCount(FetchDescriptor<ServiceRecord>()) == 1)

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: item.nextServiceDate)
        ).day
        #expect(days == 30)
        #expect(item.isOverdue == false)
    }

    @Test func aBackfilledServiceNeverRewindsTheSchedule() throws {
        let context = try equipmentContext()
        let calendar = Calendar.current
        let now = Date()

        let item = Equipment(name: "Fan", serviceIntervalDays: 30, lastServicedAt: now)
        context.insert(item)
        try context.save()

        let earlier = calendar.date(byAdding: .day, value: -10, to: now) ?? now
        try EquipmentService.add(date: earlier, note: "Forgot to log this", to: item, in: context)

        #expect(item.lastServicedAt == now)
        #expect(try context.fetchCount(FetchDescriptor<ServiceRecord>()) == 1)
    }

    @Test func correctingAServiceDateReDerivesTheSchedule() throws {
        let context = try equipmentContext()
        let calendar = Calendar.current
        let now = Date()
        let earlier = calendar.date(byAdding: .day, value: -60, to: now) ?? now

        let item = Equipment(name: "Fan", serviceIntervalDays: 30, lastServicedAt: earlier)
        context.insert(item)
        try context.save()

        try EquipmentService.add(date: earlier, note: "", to: item, in: context)
        let second = try EquipmentService.add(date: now, note: "", to: item, in: context)

        #expect(item.lastServicedAt == now)

        try EquipmentService.update(second, date: earlier, note: "Typed the wrong day", in: context)

        #expect(second.date == earlier)
        #expect(second.note == "Typed the wrong day")
        #expect(item.lastServicedAt == earlier)
    }

    @Test func removingTheLatestServiceFallsBackToTheHistory() throws {
        let context = try equipmentContext()
        let calendar = Calendar.current
        let now = Date()
        let earlier = calendar.date(byAdding: .day, value: -60, to: now) ?? now

        let item = Equipment(name: "Fan", serviceIntervalDays: 30, lastServicedAt: earlier)
        context.insert(item)
        try context.save()

        try EquipmentService.add(date: earlier, note: "First", to: item, in: context)
        let latest = try EquipmentService.add(date: now, note: "Second", to: item, in: context)
        #expect(item.lastServicedAt == now)

        try EquipmentService.delete(latest, in: context)

        #expect(item.lastServicedAt == earlier)

        let remaining = try context.fetch(FetchDescriptor<ServiceRecord>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.note == "First")
    }

    @Test func removingTheOnlyServiceKeepsTheStoredDate() throws {
        let context = try equipmentContext()
        let now = Date()

        let item = Equipment(name: "Fan", serviceIntervalDays: 30, lastServicedAt: now)
        context.insert(item)
        try context.save()

        let record = try EquipmentService.add(date: now, note: "", to: item, in: context)
        try EquipmentService.delete(record, in: context)

        #expect(item.lastServicedAt == now)
        #expect(try context.fetchCount(FetchDescriptor<ServiceRecord>()) == 0)
    }

    @Test func deletingEquipmentTakesItsServiceHistory() throws {
        let context = try equipmentContext()
        let now = Date()

        let item = Equipment(name: "Fan", serviceIntervalDays: 30, lastServicedAt: now)
        context.insert(item)
        try context.save()

        try EquipmentService.add(date: now, note: "One", to: item, in: context)
        try EquipmentService.add(
            date: now.addingTimeInterval(-86_400),
            note: "Two",
            to: item,
            in: context
        )

        try EquipmentService.delete(item, in: context)

        #expect(try context.fetchCount(FetchDescriptor<Equipment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ServiceRecord>()) == 0)
    }

    @Test func theSummaryCountsTheHistoryItWouldRemove() throws {
        let context = try equipmentContext()
        let now = Date()

        let item = Equipment(name: "Fan", serviceIntervalDays: 30, lastServicedAt: now)
        context.insert(item)
        try context.save()

        #expect(EquipmentService.summary(for: item).serviceRecords == 0)

        try EquipmentService.add(date: now, note: "", to: item, in: context)
        try EquipmentService.add(date: now.addingTimeInterval(-86_400), note: "", to: item, in: context)

        #expect(EquipmentService.summary(for: item).serviceRecords == 2)
    }

    @Test func anEmptyHistoryHasNoLatestService() {
        #expect(EquipmentService.latestServiceDate(in: []) == nil)
    }

    private func equipmentContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}
