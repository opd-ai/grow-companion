//
//  QuickLog.swift
//  Grow Companion
//
//  One-step logging for the four routine actions. The service owns prefills,
//  the plant-count preview and the only writes; the sheet collects them and
//  saves nothing until the grower confirms.
//

import Foundation
import SwiftData

enum QuickLogAction: String, CaseIterable, Identifiable {
    case water
    case reading
    case note
    case stage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: return "Water / feed"
        case .reading: return "Reading"
        case .note: return "Note"
        case .stage: return "Stage"
        }
    }

    var subtitle: String {
        switch self {
        case .water: return "Volume, pH and EC"
        case .reading: return "Temperature, humidity, light"
        case .note: return "A line for the journal"
        case .stage: return "Move a plant on"
        }
    }

    var systemImage: String {
        switch self {
        case .water: return "drop"
        case .reading: return "thermometer.medium"
        case .note: return "square.and.pencil"
        case .stage: return "arrow.triangle.2.circlepath"
        }
    }
}

struct QuickLogFeedPrefill {
    let kind: FeedKind
    let volumeLiters: Double?
    let phIn: Double?
    let ecIn: Double?
    let date: Date
}

struct QuickLogReadingPrefill {
    let temperatureC: Double?
    let humidityPercent: Double?
    let lightPPFD: Double?
    let date: Date
}

struct PlantCountPreview {
    let countedBefore: Int
    let countedAfter: Int
    let plantLimit: Int?
    let warningThreshold: Double

    var level: ComplianceLevel {
        ComplianceReport.level(
            value: Double(countedAfter),
            limit: plantLimit.map(Double.init),
            threshold: warningThreshold
        )
    }

    var isOverLimit: Bool {
        guard let plantLimit else { return false }
        return countedAfter > plantLimit
    }
}

enum QuickLogError: LocalizedError {
    case missingRoom
    case missingPlant
    case sameStage
    case emptyNote

    var errorDescription: String? {
        switch self {
        case .missingRoom:
            return "Pick the room this belongs to first."
        case .missingPlant:
            return "Pick the plant this belongs to first."
        case .sameStage:
            return "The plant is already in that stage."
        case .emptyNote:
            return "Write a line for the note first."
        }
    }
}

/// Remembers the last room and plant by name. Names are the user's own labels;
/// a renamed record simply falls back to the first available one.
enum QuickLogPreferences {
    static var roomName: String? {
        UserDefaults.standard.string(forKey: SettingsKey.quickLogRoomName)
    }

    static var plantName: String? {
        UserDefaults.standard.string(forKey: SettingsKey.quickLogPlantName)
    }

    static func remember(room: Room) {
        UserDefaults.standard.set(room.name, forKey: SettingsKey.quickLogRoomName)
    }

    static func remember(plant: Plant) {
        UserDefaults.standard.set(plant.name, forKey: SettingsKey.quickLogPlantName)
        if let room = plant.room {
            remember(room: room)
        }
    }

    static func resolvedRoom(named name: String?, in rooms: [Room]) -> Room? {
        guard let name else { return nil }
        return rooms.first { $0.name == name }
    }

    static func resolvedPlant(named name: String?, in plants: [Plant]) -> Plant? {
        guard let name else { return nil }
        return plants.first { $0.name == name }
    }

    /// Clears the remembered choices, for delete-all and for test isolation.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: SettingsKey.quickLogRoomName)
        UserDefaults.standard.removeObject(forKey: SettingsKey.quickLogPlantName)
    }
}

enum QuickLogService {
    // MARK: Prefills

    static func feedPrefill(for room: Room) -> QuickLogFeedPrefill? {
        guard let event = room.sortedFeedEvents.first else { return nil }
        return QuickLogFeedPrefill(
            kind: event.kind,
            volumeLiters: event.volumeLiters,
            phIn: event.phIn,
            ecIn: event.ecIn,
            date: event.date
        )
    }

    static func readingPrefill(for room: Room) -> QuickLogReadingPrefill? {
        guard let reading = room.latestEnvironmentReading else { return nil }
        return QuickLogReadingPrefill(
            temperatureC: reading.temperatureC,
            humidityPercent: reading.humidityPercent,
            lightPPFD: reading.lightPPFD,
            date: reading.date
        )
    }

    // MARK: Plant count preview

    /// What the jurisdiction would count after a stage change, without writing
    /// anything. The canopy is unchanged by a stage move, so only the plant
    /// count is compared here.
    static func countPreview(
        plant: Plant,
        to newStage: PlantStage,
        plants: [Plant],
        rule: JurisdictionRule,
        warningThreshold: Double
    ) -> PlantCountPreview {
        let before = plants.filter { ComplianceEngine.counts($0, rule: rule) }.count
        let wasCounted = ComplianceEngine.counts(plant, rule: rule)
        let willCount = counts(plant: plant, stage: newStage, rule: rule)
        let after = before - (wasCounted ? 1 : 0) + (willCount ? 1 : 0)

        return PlantCountPreview(
            countedBefore: before,
            countedAfter: after,
            plantLimit: rule.plantLimit,
            warningThreshold: warningThreshold
        )
    }

    /// What the jurisdiction would count if a plant in this stage were added,
    /// without writing anything.
    static func countPreview(
        addingStage stage: PlantStage,
        plants: [Plant],
        rule: JurisdictionRule,
        warningThreshold: Double
    ) -> PlantCountPreview {
        let before = plants.filter { ComplianceEngine.counts($0, rule: rule) }.count
        let after = before + (counts(stage: stage, rule: rule) ? 1 : 0)

        return PlantCountPreview(
            countedBefore: before,
            countedAfter: after,
            plantLimit: rule.plantLimit,
            warningThreshold: warningThreshold
        )
    }

    private static func counts(plant: Plant, stage: PlantStage, rule: JurisdictionRule) -> Bool {
        guard plant.harvestDisposition != .destroyed else { return false }
        return counts(stage: stage, rule: rule)
    }

    private static func counts(stage: PlantStage, rule: JurisdictionRule) -> Bool {
        guard rule.cultivable else { return false }
        guard stage != .storage else { return false }
        guard rule.countedStages.contains(stage) else { return false }
        if stage == .clone && !rule.countsClones { return false }
        return true
    }

    // MARK: Writes

    @discardableResult
    static func logFeed(
        room: Room,
        kind: FeedKind,
        volumeLiters: Double?,
        phIn: Double?,
        ecIn: Double?,
        in context: ModelContext
    ) throws -> FeedEvent {
        let event = FeedEvent(
            date: Date(),
            kind: kind,
            volumeLiters: volumeLiters,
            phIn: phIn,
            ecIn: ecIn,
            room: room
        )
        context.insert(event)
        try save(context)
        QuickLogPreferences.remember(room: room)
        return event
    }

    @discardableResult
    static func logReading(
        room: Room,
        temperatureC: Double?,
        humidityPercent: Double?,
        lightPPFD: Double?,
        in context: ModelContext
    ) throws -> EnvironmentReading {
        let reading = EnvironmentReading(
            date: Date(),
            temperatureC: temperatureC,
            humidityPercent: humidityPercent,
            lightPPFD: lightPPFD,
            source: .manual,
            room: room
        )
        context.insert(reading)
        EnvironmentAlertService.evaluate(reading: reading, room: room, context: context)
        try save(context)
        QuickLogPreferences.remember(room: room)
        return reading
    }

    @discardableResult
    static func logNote(
        text: String,
        plant: Plant?,
        room: Room?,
        in context: ModelContext
    ) throws -> JournalEntry {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QuickLogError.emptyNote }

        let entry = JournalEntry(
            kind: .note,
            text: trimmed,
            plant: plant,
            room: room ?? plant?.room
        )
        context.insert(entry)
        try save(context)
        if let plant {
            QuickLogPreferences.remember(plant: plant)
        } else if let room = entry.room {
            QuickLogPreferences.remember(room: room)
        }
        return entry
    }

    @discardableResult
    static func changeStage(
        plant: Plant,
        to newStage: PlantStage,
        in context: ModelContext
    ) throws -> StageEvent {
        guard plant.stage != newStage else { throw QuickLogError.sameStage }

        let event = StageEvent(stage: newStage, date: Date(), plant: plant)
        context.insert(event)
        plant.stage = newStage
        if newStage == .harvest {
            plant.harvestedAt = Date()
        }
        try save(context)
        QuickLogPreferences.remember(plant: plant)
        return event
    }

    private static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
