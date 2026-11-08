//
//  JournalEntry.swift
//  Grow Companion
//
//  A timestamped note, observation or photo attached to a plant, a room or the
//  whole grow. Photos are stored as files with location metadata removed.
//

import Foundation
import SwiftData

@Model
final class JournalEntry {
    var kindRaw: String = JournalKind.note.rawValue
    var text: String = ""
    var tagRaw: String?
    var photoFileName: String?
    var createdAt: Date = Date()
    var plant: Plant?
    var room: Room?

    init(
        kind: JournalKind = .note,
        text: String = "",
        tag: ObservationTag? = nil,
        photoFileName: String? = nil,
        createdAt: Date = Date(),
        plant: Plant? = nil,
        room: Room? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.text = text
        self.tagRaw = tag?.rawValue
        self.photoFileName = photoFileName
        self.createdAt = createdAt
        self.plant = plant
        self.room = room
    }

    var kind: JournalKind {
        get { JournalKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    var tag: ObservationTag? {
        get {
            guard let raw = tagRaw else { return nil }
            return ObservationTag(rawValue: raw)
        }
        set { tagRaw = newValue?.rawValue }
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photoFileName == nil
    }
}
