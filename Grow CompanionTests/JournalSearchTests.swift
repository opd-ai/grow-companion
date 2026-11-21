//
//  JournalSearchTests.swift
//  Grow CompanionTests
//
//  Journal search is a pure function of the query and the entries: every word
//  has to be found, case and accents do not decide a match, and an empty query
//  never hides a record.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct JournalSearchTests {
    @Test func anEmptyQueryKeepsEveryEntry() {
        let entry = JournalEntry(kind: .note, text: "Pale leaves after the flush")

        #expect(JournalSearch.matches(entry, query: ""))
        #expect(JournalSearch.matches(entry, query: "   "))
        #expect(JournalSearch.filter([entry], query: "").count == 1)
    }

    @Test func textMatchesIgnoringCaseAndAccents() {
        let entry = JournalEntry(kind: .note, text: "Mosca blanca on the underside")

        #expect(JournalSearch.matches(entry, query: "mosca"))
        #expect(JournalSearch.matches(entry, query: "MOSCA"))
        #expect(JournalSearch.matches(entry, query: "blánca"))
        #expect(JournalSearch.matches(entry, query: "underside") == false)
        #expect(JournalSearch.matches(entry, query: "blanca"))
    }

    @Test func everyWordOfTheQueryHasToAppear() {
        let entry = JournalEntry(kind: .note, text: "Burnt leaf tips after the neem spray")

        #expect(JournalSearch.matches(entry, query: "neem burnt"))
        #expect(JournalSearch.matches(entry, query: "burnt neem"))
        #expect(JournalSearch.matches(entry, query: "neem mites") == false)
    }

    @Test func aTagIsSearchableByItsTitle() throws {
        let tag = try #require(ObservationTag.allCases.first)
        let entry = JournalEntry(kind: .observation, text: "", tag: tag)

        #expect(JournalSearch.matches(entry, query: tag.title))
        #expect(JournalSearch.matches(entry, query: JournalSearch.folded(tag.title)))
    }

    @Test func thePlantAndRoomAreSearchable() {
        let room = Room(name: "Flower tent")
        let plant = Plant(name: "Blue Dream #2", strainName: "Blue Dream", room: room)
        let entry = JournalEntry(kind: .note, text: "Two more weeks", plant: plant, room: room)

        #expect(JournalSearch.matches(entry, query: "dream"))
        #expect(JournalSearch.matches(entry, query: "flower tent"))
        #expect(JournalSearch.matches(entry, query: "blue 2"))
        #expect(JournalSearch.matches(entry, query: "veg tent") == false)
    }

    @Test func theKindIsSearchable() throws {
        let kind = JournalKind.note
        let entry = JournalEntry(kind: kind, text: "Anything")

        #expect(JournalSearch.matches(entry, query: kind.title))
    }

    @Test func filteringKeepsOnlyMatchingEntries() {
        let first = JournalEntry(kind: .note, text: "Watered with pH 6.2")
        let second = JournalEntry(kind: .note, text: "Spotted thrips")
        let third = JournalEntry(kind: .note, text: "Watered again")

        let matches = JournalSearch.filter([first, second, third], query: "watered")

        #expect(matches.count == 2)
        #expect(matches.allSatisfy { $0.text.contains("Watered") })
    }
}
