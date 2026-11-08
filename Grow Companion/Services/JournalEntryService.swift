//
//  JournalEntryService.swift
//  Grow Companion
//
//  Deleting a journal entry also removes its protected photo files and cache
//  entry, so the record and its image disappear together.
//

import Foundation
import SwiftData

enum JournalEntryService {
    static func delete(_ entry: JournalEntry, in context: ModelContext) throws {
        let photoFileName = entry.photoFileName

        context.delete(entry)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        // Only after the store no longer references it. A failed save leaves
        // the photo in place rather than orphaning a visible record.
        if let photoFileName {
            PhotoStore.delete(named: photoFileName)
        }
    }
}
