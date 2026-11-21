//
//  JournalSearch.swift
//  Grow Companion
//
//  Text search over the cultivation journal. Pure and local: it reads the
//  entries it is given and never touches the store, so the filter is a
//  function of the query and the records alone.
//

import Foundation

enum JournalSearch {
    /// What a search looks through: the note itself and the words a grower
    /// would use to find it again.
    static func haystack(for entry: JournalEntry) -> [String] {
        var parts = [entry.text, entry.kind.title]
        if let tag = entry.tag { parts.append(tag.title) }
        if let plant = entry.plant {
            parts.append(plant.displayName)
            parts.append(plant.displayStrain)
        }
        if let room = entry.room { parts.append(room.name) }
        return parts
    }

    /// Every word of the query has to appear somewhere in the entry, in any
    /// order, ignoring case, accents and surrounding spaces. An empty query
    /// matches everything, which is what an empty search field means.
    static func matches(_ entry: JournalEntry, query: String) -> Bool {
        let words = tokens(query)
        guard !words.isEmpty else { return true }

        let searchable = folded(haystack(for: entry).joined(separator: " "))
        return words.allSatisfy { searchable.contains($0) }
    }

    static func filter(_ entries: [JournalEntry], query: String) -> [JournalEntry] {
        let words = tokens(query)
        guard !words.isEmpty else { return entries }
        return entries.filter { matches($0, query: query) }
    }

    /// The query split into folded words, so `Neem  burn` finds an entry
    /// written as "burnt leaves after neem".
    static func tokens(_ query: String) -> [String] {
        folded(query)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    /// Case, accent and width insensitive, so `mosca` finds "Mosca blanca"
    /// and `mould` finds "mould" written with a different case.
    static func folded(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: nil
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    }
}
