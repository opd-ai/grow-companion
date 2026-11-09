//
//  GrowerBreeders.swift
//  Grow Companion
//
//  Writing and validating the grower's own breeder notes: one trimmed draft,
//  one record per breeder, and explicit errors instead of a silent save. The
//  bundled reference stays read-only; a note only ever sits beside it.
//

import Foundation
import SwiftData

enum GrowerBreederError: LocalizedError {
    case missingName
    case nameTooLong
    case notesTooLong
    case invalidWebsite

    var errorDescription: String? {
        switch self {
        case .missingName:
            return String(localized: "Add the breeder's name before saving.")
        case .nameTooLong:
            return String(localized: "The breeder name is longer than 80 characters.")
        case .notesTooLong:
            return String(localized: "Your notes are longer than 4,000 characters.")
        case .invalidWebsite:
            return String(localized: "Use an https address, such as https://example.com.")
        }
    }
}

/// What the editor holds after trimming: the only shape a save accepts.
struct GrowerBreederDraft: Hashable {
    let name: String
    let notes: String
    let website: String?

    init(name: String, notes: String, website: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GrowerBreederError.missingName }
        guard trimmedName.count <= GrowerBreederService.maximumNameLength else {
            throw GrowerBreederError.nameTooLong
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNotes.count <= GrowerBreederService.maximumNotesLength else {
            throw GrowerBreederError.notesTooLong
        }

        let trimmedWebsite = website.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedWebsite.isEmpty {
            self.website = nil
        } else {
            guard let url = GrowerBreederService.websiteURL(from: trimmedWebsite) else {
                throw GrowerBreederError.invalidWebsite
            }
            self.website = url.absoluteString
        }

        self.name = trimmedName
        self.notes = trimmedNotes
    }

    /// Nothing worth keeping, so the save removes the record instead.
    var isEmpty: Bool { notes.isEmpty && website == nil }
}

enum GrowerBreederService {
    static let maximumNameLength = 80
    static let maximumNotesLength = 4000

    /// Costs nothing and is safe to call on every keystroke: an address without
    /// a scheme is read as https, anything else has to be https already.
    static func websiteURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate),
              url.scheme?.lowercased() == "https",
              let host = url.host(),
              !host.isEmpty else {
            return nil
        }
        return url
    }

    /// The record for a breeder name, matched the way the reference is matched,
    /// newest first so a duplicate can never hide an edit.
    static func current(named name: String, in stored: [GrowerBreeder]) -> GrowerBreeder? {
        let lookup = BreederLibrary.key(for: name)
        guard !lookup.isEmpty else { return nil }
        return stored
            .filter { BreederLibrary.key(for: $0.name) == lookup }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    /// Saves the grower's notes for one breeder and returns the record that now
    /// holds them, or nil when an empty save removed it. A bundled breeder keeps
    /// its canonical name, so the reference, the strains and the profile stay
    /// matched by one key.
    @discardableResult
    static func save(
        name: String,
        notes: String,
        website: String,
        existing: GrowerBreeder?,
        in context: ModelContext
    ) throws -> GrowerBreeder? {
        let draft = try GrowerBreederDraft(name: name, notes: notes, website: website)
        let storedName = BreederLibrary.profile(named: draft.name)?.name ?? draft.name

        let all = (try? context.fetch(FetchDescriptor<GrowerBreeder>())) ?? []
        let target = existing ?? current(named: storedName, in: all)

        guard !draft.isEmpty else {
            if let target {
                context.delete(target)
                try save(context)
            }
            return nil
        }

        let record: GrowerBreeder
        if let target {
            record = target
        } else {
            record = GrowerBreeder(name: storedName)
            context.insert(record)
        }

        record.name = storedName
        record.notes = draft.notes
        record.website = draft.website
        record.updatedAt = Date()
        try save(context)
        return record
    }

    /// Removes the grower's notes; a bundled breeder keeps its reference copy.
    static func delete(_ record: GrowerBreeder, in context: ModelContext) throws {
        context.delete(record)
        try save(context)
    }

    /// A failed save leaves the context as it was, so no half-written record
    /// survives to be exported or counted.
    private static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
