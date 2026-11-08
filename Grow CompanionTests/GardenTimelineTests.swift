//
//  GardenTimelineTests.swift
//  Grow CompanionTests
//
//  The merge is a pure function over live queries: every timestamped type is
//  present once, in order, and the local filter never writes.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

struct GardenTimelineTests {
    @Test func mergesEveryTimestampedTypeExactlyOnce() throws {
        let context = try makeContext()
        let room = Room(name: "Tent")
        let plant = Plant(name: "One", stage: .veg, room: room)
        context.insert(room)
        context.insert(plant)

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let stageEvent = StageEvent(stage: .flower, date: base.addingTimeInterval(1), plant: plant)
        let journal = JournalEntry(
            kind: .note,
            text: "Lower leaves pale",
            createdAt: base.addingTimeInterval(2),
            plant: plant
        )
        let feed = FeedEvent(
            date: base.addingTimeInterval(3),
            kind: .water,
            volumeLiters: 2,
            room: room
        )
        let reading = EnvironmentReading(
            date: base.addingTimeInterval(4),
            temperatureC: 24,
            humidityPercent: 55,
            room: room
        )
        let calibration = CalibrationEvent(
            date: base.addingTimeInterval(5),
            meter: .phMeter,
            reading: 6.2,
            room: room
        )
        let light = LightScheduleEvent(
            date: base.addingTimeInterval(6),
            previousOnMinutes: 360,
            previousOffMinutes: 0,
            newOnMinutes: 480,
            newOffMinutes: 0,
            room: room
        )
        let training = TrainingSession(
            method: .topping,
            date: base.addingTimeInterval(7),
            plant: plant
        )
        let treatment = Treatment(
            productName: "Neem",
            date: base.addingTimeInterval(8),
            plant: plant
        )
        let scouting = ScoutingCheck(
            date: base.addingTimeInterval(9),
            findings: [.pests],
            plant: plant
        )
        let drying = DryingSession(startedAt: base, plant: plant)
        let dryingCheck = DryingCheck(
            date: base.addingTimeInterval(10),
            humidityPercent: 60,
            temperatureC: 20,
            session: drying
        )
        let burp = CureBurp(date: base.addingTimeInterval(11), session: drying)

        context.insert(stageEvent)
        context.insert(journal)
        context.insert(feed)
        context.insert(reading)
        context.insert(calibration)
        context.insert(light)
        context.insert(training)
        context.insert(treatment)
        context.insert(scouting)
        context.insert(drying)
        context.insert(dryingCheck)
        context.insert(burp)
        try context.save()

        let sources = GardenTimelineSources(
            stageEvents: [stageEvent],
            journal: [journal],
            feeds: [feed],
            readings: [reading],
            calibrations: [calibration],
            lightEvents: [light],
            training: [training],
            treatments: [treatment],
            scouting: [scouting],
            dryingChecks: [dryingCheck],
            cureBurps: [burp]
        )
        let events = GardenTimelineService.events(from: sources)

        #expect(events.count == 11)
        #expect(Set(events.map(\.id)).count == 11)
        #expect(events.map(\.kind) == [
            .cureBurp, .dryingCheck, .scouting, .treatment, .training,
            .lightSchedule, .calibration, .reading, .feed, .journal, .stage
        ])

        for (earlier, later) in zip(events, events.dropFirst()) {
            #expect(earlier.date >= later.date)
        }

        let stageRow = try #require(events.first { $0.kind == .stage })
        #expect(stageRow.plantName == "One")
        #expect(stageRow.roomName == "Tent")

        let dryingRow = try #require(events.first { $0.kind == .dryingCheck })
        #expect(dryingRow.plant?.persistentModelID == plant.persistentModelID)
        #expect(dryingRow.roomName == "Tent")

        let feedRow = try #require(events.first { $0.kind == .feed })
        #expect(feedRow.roomName == "Tent")
        #expect(feedRow.title == "Watered")
    }

    @Test func filtersByRoomPlantAndTypeWithoutWriting() throws {
        let context = try makeContext()
        let tent = Room(name: "Tent")
        let shed = Room(name: "Shed")
        let plant = Plant(name: "One", stage: .veg, room: tent)
        context.insert(tent)
        context.insert(shed)
        context.insert(plant)

        let feedInTent = FeedEvent(date: Date(), room: tent)
        let feedInShed = FeedEvent(date: Date().addingTimeInterval(-60), room: shed)
        let journal = JournalEntry(kind: .note, text: "Note", plant: plant)
        context.insert(feedInTent)
        context.insert(feedInShed)
        context.insert(journal)
        try context.save()

        let events = GardenTimelineService.events(
            from: GardenTimelineSources(
                journal: [journal],
                feeds: [feedInTent, feedInShed]
            )
        )
        #expect(events.count == 3)

        let roomFilter = GardenTimelineFilter(roomID: tent.persistentModelID)
        #expect(events.filter { roomFilter.matches($0) }.count == 2)

        let plantFilter = GardenTimelineFilter(plantID: plant.persistentModelID)
        #expect(events.filter { plantFilter.matches($0) }.count == 1)

        let typeFilter = GardenTimelineFilter(kinds: [.feed])
        #expect(events.filter { typeFilter.matches($0) }.count == 2)

        let combined = GardenTimelineFilter(
            roomID: shed.persistentModelID,
            kinds: [.journal]
        )
        #expect(events.filter { combined.matches($0) }.isEmpty)

        // The filter is a value type and the service is pure: no writes happen.
        let feedCount = try context.fetchCount(FetchDescriptor<FeedEvent>())
        let journalCount = try context.fetchCount(FetchDescriptor<JournalEntry>())
        #expect(feedCount == 2)
        #expect(journalCount == 1)
    }

    @Test func aRoomFilterMatchesEitherTheRecordRoomOrThePlantRoom() throws {
        let context = try makeContext()
        let tent = Room(name: "Tent")
        let shed = Room(name: "Shed")
        let plant = Plant(name: "One", stage: .veg, room: tent)
        context.insert(tent)
        context.insert(shed)
        context.insert(plant)

        let check = ScoutingCheck(date: Date(), findings: [.pests], plant: plant, room: shed)
        context.insert(check)
        try context.save()

        let events = GardenTimelineService.events(
            from: GardenTimelineSources(scouting: [check])
        )
        let row = try #require(events.first)
        #expect(row.plant?.persistentModelID == plant.persistentModelID)
        #expect(row.room?.persistentModelID == shed.persistentModelID)

        // The record names the shed, but the plant lives in the tent; either
        // room filter should find it.
        #expect(GardenTimelineFilter(roomID: shed.persistentModelID).matches(row))
        #expect(GardenTimelineFilter(roomID: tent.persistentModelID).matches(row))
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }
}
