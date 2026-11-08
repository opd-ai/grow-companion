//
//  GrowCalendarTests.swift
//  Grow CompanionTests
//
//  The calendar merges every dated record once; a confirmed reschedule moves
//  one reminder and schedules exactly one notification.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct GrowCalendarEntryTests {
    @Test func entriesMergeEverySourceExactlyOnce() throws {
        let context = try calendarContext()
        let calendar = Calendar.current
        let now = Date()

        let room = Room(name: "Tent")
        context.insert(room)

        let reminder = CareReminder(
            title: "Water",
            kind: .water,
            nextDueDate: calendar.date(byAdding: .day, value: 2, to: now) ?? now,
            room: room
        )
        context.insert(reminder)

        let plant = Plant(name: "Flower", stage: .flower, room: room)
        context.insert(plant)
        context.insert(
            StageEvent(
                stage: .flower,
                date: calendar.date(byAdding: .day, value: -20, to: now) ?? now,
                plant: plant
            )
        )

        let session = DryingSession(
            startedAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
            plant: plant
        )
        context.insert(session)

        try context.save()

        let entries = GrowCalendarService.entries(
            from: GrowCalendarSources(
                reminders: [reminder],
                plants: [plant],
                dryingSessions: [session]
            ),
            now: now
        )

        #expect(entries.contains { $0.kind == .reminder })
        #expect(entries.contains { $0.kind == .stageWindow })
        #expect(entries.contains { $0.kind == .harvestWindow })
        #expect(entries.contains { $0.kind == .dryingCheck })
        #expect(Set(entries.map(\.id)).count == entries.count)

        let dates = entries.map(\.date)
        #expect(dates == dates.sorted())
    }

    @Test func disabledRemindersDoNotAppear() throws {
        let context = try calendarContext()
        let reminder = CareReminder(title: "Water", isEnabled: false)
        context.insert(reminder)
        try context.save()

        let entries = GrowCalendarService.entries(
            from: GrowCalendarSources(reminders: [reminder])
        )
        #expect(entries.isEmpty)
    }

    @Test func curingChecksFollowTheBurpInterval() throws {
        let context = try calendarContext()
        let calendar = Calendar.current
        let now = Date()

        let plant = Plant(name: "Cured", stage: .cure)
        context.insert(plant)

        let session = DryingSession(
            startedAt: calendar.date(byAdding: .day, value: -20, to: now) ?? now,
            phase: .curing,
            plant: plant
        )
        context.insert(session)
        try context.save()

        let entries = GrowCalendarService.entries(
            from: GrowCalendarSources(plants: [plant], dryingSessions: [session]),
            now: now
        )

        let check = try #require(entries.first { $0.kind == .cureCheck })
        #expect(check.id == "cure-\(String(describing: session.persistentModelID))")
    }
}

@Suite(.serialized)
struct GrowCalendarRescheduleTests {
    @Test func rescheduleKeepsTheTimeAndSchedulesExactlyOneNotification() throws {
        let context = try calendarContext()
        let calendar = Calendar.current
        let now = Date()

        let reminder = CareReminder(title: "Water", kind: .water, timeOfDayMinutes: 9 * 60)
        context.insert(reminder)
        try context.save()

        let target = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        let spy = SchedulingSpy()

        let newDate = try GrowCalendarService.reschedule(
            reminder: reminder,
            to: target,
            schedulers: spy,
            now: now,
            in: context
        )

        #expect(calendar.isDate(newDate, inSameDayAs: target))
        #expect(calendar.component(.hour, from: newDate) == 9)
        #expect(calendar.component(.minute, from: newDate) == 0)
        #expect(reminder.nextDueDate == newDate)
        #expect(spy.cancelled == [reminder.notificationIdentifier])
        #expect(spy.scheduled == [reminder.notificationIdentifier])
    }

    @Test func rescheduleToAPastDayChangesNothing() throws {
        let context = try calendarContext()
        let calendar = Calendar.current
        let now = Date()

        let reminder = CareReminder(title: "Water", timeOfDayMinutes: 9 * 60)
        context.insert(reminder)
        try context.save()

        let before = reminder.nextDueDate
        let spy = SchedulingSpy()
        let past = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        #expect(throws: GrowCalendarError.self) {
            try GrowCalendarService.reschedule(
                reminder: reminder,
                to: past,
                schedulers: spy,
                now: now,
                in: context
            )
        }

        #expect(reminder.nextDueDate == before)
        #expect(spy.cancelled.isEmpty)
        #expect(spy.scheduled.isEmpty)
    }

    @Test func overdueRemindersStayListedUntilTheyAreCompleted() throws {
        let context = try calendarContext()
        let calendar = Calendar.current
        let now = Date()

        let reminder = CareReminder(
            title: "Water",
            nextDueDate: calendar.date(byAdding: .day, value: -2, to: now) ?? now
        )
        context.insert(reminder)
        try context.save()

        #expect(GrowCalendarService.overdueReminders(from: [reminder], now: now).count == 1)

        CareLog.complete(reminder)
        try context.save()

        #expect(GrowCalendarService.overdueReminders(from: [reminder], now: now).isEmpty)
    }
}

private final class SchedulingSpy: ReminderScheduling {
    private(set) var scheduled: [String] = []
    private(set) var cancelled: [String] = []

    func schedule(_ reminder: CareReminder) {
        scheduled.append(reminder.notificationIdentifier)
    }

    func cancel(_ reminder: CareReminder) {
        cancelled.append(reminder.notificationIdentifier)
    }
}

private func calendarContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: DataInventory.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    return ModelContext(container)
}
