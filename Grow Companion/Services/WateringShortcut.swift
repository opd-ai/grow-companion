//
//  WateringShortcut.swift
//  Grow Companion
//
//  The Siri and Shortcuts half of story 3: one watering, in the right room,
//  logged with the current time, and a question instead of a guess when the
//  room is ambiguous. The intent is a thin wrapper over this service.
//

import Foundation
import SwiftData

/// How a shortcut decided which room a watering belongs to.
enum WateringRoomChoice: Equatable {
    case room(String)
    /// Several rooms with nothing to choose between them; the caller asks.
    case ask([String])
    case none
}

struct WateringShortcutResult: Equatable {
    let roomName: String
    let at: Date
}

enum WateringShortcutError: LocalizedError, Equatable {
    case noRooms
    case unknownRoom(String, available: [String])
    case ambiguousRoom([String])
    case storeUnavailable

    var errorDescription: String? {
        switch self {
        case .noRooms:
            return String(localized: "Add a room in Grow Companion before logging a watering.")
        case .unknownRoom(let name, let available):
            return String(localized: "There is no room called \(name). Rooms: \(available.joined(separator: ", ")).")
        case .ambiguousRoom(let names):
            return String(localized: "Say which room: \(names.joined(separator: ", ")).")
        case .storeUnavailable:
            return String(localized: "Grow Companion could not open your records. Open the app to check them.")
        }
    }
}

enum WateringShortcutService {
    /// An explicit room wins, then the room the app remembers, then the only
    /// room there is. Several rooms with nothing to choose between them is a
    /// question, never a guess.
    static func resolveRoom(
        requested: String?,
        remembered: String?,
        roomNames: [String]
    ) -> WateringRoomChoice {
        let names = roomNames.sorted()
        guard !names.isEmpty else { return .none }

        if let requested = normalized(requested) {
            if let match = names.first(where: { $0.caseInsensitiveCompare(requested) == .orderedSame }) {
                return .room(match)
            }
            return .ask(names)
        }

        if let remembered = normalized(remembered),
           let match = names.first(where: { $0.caseInsensitiveCompare(remembered) == .orderedSame }) {
            return .room(match)
        }

        if names.count == 1 { return .room(names[0]) }
        return .ask(names)
    }

    /// Resolves the room and writes one watering through the service the Quick
    /// Log sheet uses, so the timeline, the reminders and the count all see it.
    /// Writes nothing unless the room is unambiguous.
    @discardableResult
    static func logWatering(
        requestedRoom: String?,
        in context: ModelContext,
        now: Date = Date()
    ) throws -> WateringShortcutResult {
        let rooms = try context.fetch(FetchDescriptor<Room>())
        let requested = normalized(requestedRoom)
        let choice = resolveRoom(
            requested: requested,
            remembered: QuickLogPreferences.roomName,
            roomNames: rooms.map(\.name)
        )

        switch choice {
        case .none:
            throw WateringShortcutError.noRooms
        case .ask(let names):
            if let requested {
                throw WateringShortcutError.unknownRoom(requested, available: names)
            }
            throw WateringShortcutError.ambiguousRoom(names)
        case .room(let name):
            guard let room = rooms.first(where: { $0.name == name }) else {
                throw WateringShortcutError.noRooms
            }
            try QuickLogService.logFeed(
                room: room,
                kind: .water,
                volumeLiters: nil,
                phIn: nil,
                ecIn: nil,
                in: context
            )
            return WateringShortcutResult(roomName: room.name, at: now)
        }
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
