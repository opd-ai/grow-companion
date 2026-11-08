//
//  WateringShortcutTests.swift
//  Grow CompanionTests
//
//  Story 3's Siri and Shortcuts path: the right room, the current time, and a
//  question rather than a guess when several rooms could match.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct WateringShortcutTests {
    @Test func explicitRoomIsUsed() throws {
        let context = try shortcutContext()
        let tent = Room(name: "Tent")
        let attic = Room(name: "Attic")
        context.insert(tent)
        context.insert(attic)
        try context.save()
        defer { QuickLogPreferences.reset() }

        let result = try WateringShortcutService.logWatering(requestedRoom: "tent", in: context)

        #expect(result.roomName == "Tent")
        let events = try context.fetch(FetchDescriptor<FeedEvent>())
        #expect(events.count == 1)
        #expect(events.first?.kind == .water)
        #expect(events.first?.room?.name == "Tent")
        #expect(QuickLogPreferences.roomName == "Tent")
    }

    @Test func rememberedRoomIsUsedWhenNoneIsAsked() throws {
        let context = try shortcutContext()
        context.insert(Room(name: "Tent"))
        let attic = Room(name: "Attic")
        context.insert(attic)
        try context.save()
        defer { QuickLogPreferences.reset() }
        QuickLogPreferences.remember(room: attic)

        let result = try WateringShortcutService.logWatering(requestedRoom: nil, in: context)

        #expect(result.roomName == "Attic")
    }

    @Test func singleRoomIsUsedWithoutAsking() throws {
        let context = try shortcutContext()
        context.insert(Room(name: "Only tent"))
        try context.save()
        defer { QuickLogPreferences.reset() }

        let result = try WateringShortcutService.logWatering(requestedRoom: "  ", in: context)

        #expect(result.roomName == "Only tent")
    }

    @Test func severalRoomsAskInsteadOfGuessing() throws {
        let context = try shortcutContext()
        context.insert(Room(name: "Tent"))
        context.insert(Room(name: "Attic"))
        try context.save()
        defer { QuickLogPreferences.reset() }

        #expect(throws: WateringShortcutError.ambiguousRoom(["Attic", "Tent"])) {
            try WateringShortcutService.logWatering(requestedRoom: nil, in: context)
        }
        #expect(try context.fetch(FetchDescriptor<FeedEvent>()).isEmpty)
        #expect(QuickLogPreferences.roomName == nil)
    }

    @Test func unknownRoomAsksWithTheAvailableRooms() throws {
        let context = try shortcutContext()
        context.insert(Room(name: "Tent"))
        context.insert(Room(name: "Attic"))
        try context.save()
        defer { QuickLogPreferences.reset() }

        #expect(throws: WateringShortcutError.unknownRoom("Cellar", available: ["Attic", "Tent"])) {
            try WateringShortcutService.logWatering(requestedRoom: "Cellar", in: context)
        }
        #expect(try context.fetch(FetchDescriptor<FeedEvent>()).isEmpty)
    }

    @Test func noRoomsFailsWithoutWriting() throws {
        let context = try shortcutContext()
        defer { QuickLogPreferences.reset() }

        #expect(throws: WateringShortcutError.noRooms) {
            try WateringShortcutService.logWatering(requestedRoom: nil, in: context)
        }
        #expect(try context.fetch(FetchDescriptor<FeedEvent>()).isEmpty)
    }

    @Test func resolutionPrefersExplicitThenRememberedThenSingle() {
        #expect(
            WateringShortcutService.resolveRoom(
                requested: "Tent",
                remembered: "Attic",
                roomNames: ["Tent", "Attic"]
            ) == .room("Tent")
        )
        #expect(
            WateringShortcutService.resolveRoom(
                requested: nil,
                remembered: "Attic",
                roomNames: ["Tent", "Attic"]
            ) == .room("Attic")
        )
        #expect(
            WateringShortcutService.resolveRoom(
                requested: nil,
                remembered: "Gone",
                roomNames: ["Tent"]
            ) == .room("Tent")
        )
        #expect(
            WateringShortcutService.resolveRoom(
                requested: nil,
                remembered: "Gone",
                roomNames: ["Tent", "Attic"]
            ) == .ask(["Attic", "Tent"])
        )
        #expect(
            WateringShortcutService.resolveRoom(
                requested: nil,
                remembered: nil,
                roomNames: []
            ) == WateringRoomChoice.none
        )
    }

    private func shortcutContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}
