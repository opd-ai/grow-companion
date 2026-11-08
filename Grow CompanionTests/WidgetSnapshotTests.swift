//
//  WidgetSnapshotTests.swift
//  Grow CompanionTests
//
//  The widget payload holds counts by default and task names only when the
//  grower allows them.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct WidgetSnapshotTests {
    @Test func defaultsShowCountsAndNoNames() throws {
        let context = try widgetContext()
        let calendar = Calendar.current
        let now = Date()

        let due = CareReminder(title: "Water the tent", nextDueDate: now)
        let late = CareReminder(
            title: "Calibrate the meter",
            nextDueDate: calendar.date(byAdding: .day, value: -1, to: now) ?? now
        )
        let off = CareReminder(title: "Muted", isEnabled: false, nextDueDate: now)
        context.insert(due)
        context.insert(late)
        context.insert(off)
        try context.save()

        let snapshot = WidgetSnapshotService.build(
            reminders: [due, late, off],
            now: now,
            showsTitles: false
        )

        #expect(snapshot.dueToday == 1)
        #expect(snapshot.overdue == 1)
        #expect(snapshot.titles.isEmpty)
    }

    @Test func titlesAppearOnlyWhenAllowed() throws {
        let context = try widgetContext()
        let now = Date()

        let due = CareReminder(title: "Water the tent", nextDueDate: now)
        context.insert(due)
        try context.save()

        let withTitles = WidgetSnapshotService.build(
            reminders: [due],
            now: now,
            showsTitles: true
        )
        #expect(withTitles.titles == ["Water the tent"])

        let withoutTitles = WidgetSnapshotService.build(
            reminders: [due],
            now: now,
            showsTitles: false
        )
        #expect(withoutTitles.titles.isEmpty)
    }

    @Test func disabledRemindersAreNotCounted() throws {
        let context = try widgetContext()
        let now = Date()

        let muted = CareReminder(title: "Muted", isEnabled: false, nextDueDate: now)
        context.insert(muted)
        try context.save()

        let snapshot = WidgetSnapshotService.build(
            reminders: [muted],
            now: now,
            showsTitles: true
        )

        #expect(snapshot.dueToday == 0)
        #expect(snapshot.overdue == 0)
        #expect(snapshot.titles.isEmpty)
    }

    private func widgetContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}
