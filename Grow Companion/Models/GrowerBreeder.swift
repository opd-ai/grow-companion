//
//  GrowerBreeder.swift
//  Grow Companion
//
//  The grower's own notes for a breeder. Stored locally so a breeder the
//  bundled reference does not carry can still be recorded, and so a bundled
//  profile can carry the grower's own notes beside the reference copy. The two
//  are never merged into one sentence.
//

import Foundation
import SwiftData

@Model
final class GrowerBreeder {
    /// The breeder's name as the grower typed it, or the canonical bundled name
    /// when the notes belong to a bundled profile.
    var name: String = ""

    /// What the grower wants to remember about this breeder.
    var notes: String = ""

    /// An https address the grower saved for this breeder, when there is one.
    var website: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        name: String,
        notes: String = "",
        website: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.name = name
        self.notes = notes
        self.website = website
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Notes without the surrounding whitespace, for display and search.
    var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The saved address, when it is not blank.
    var trimmedWebsite: String? {
        let trimmed = (website ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// True when the record carries nothing the grower would miss: no notes and
    /// no link. Such a record is removed rather than exported as an empty row.
    var isEmpty: Bool {
        trimmedNotes.isEmpty && trimmedWebsite == nil
    }
}
