//
//  GrowerBreederTests.swift
//  Grow CompanionTests
//
//  The grower's own breeder notes: validation, the merge with the bundled
//  reference, one record per breeder, and their place in export, backup and
//  delete.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct GrowerBreederDraftTests {
    @Test func aNameIsRequired() {
        #expect(throws: GrowerBreederError.self) {
            _ = try GrowerBreederDraft(name: "   ", notes: "", website: "")
        }
    }

    @Test func theNameIsTrimmed() throws {
        let draft = try GrowerBreederDraft(name: "  Sensi Seeds  ", notes: "", website: "")

        #expect(draft.name == "Sensi Seeds")
    }

    @Test func anOverlongNameIsRejected() {
        let name = String(repeating: "a", count: GrowerBreederService.maximumNameLength + 1)

        #expect(throws: GrowerBreederError.self) {
            _ = try GrowerBreederDraft(name: name, notes: "", website: "")
        }
    }

    @Test func overlongNotesAreRejected() {
        let notes = String(repeating: "a", count: GrowerBreederService.maximumNotesLength + 1)

        #expect(throws: GrowerBreederError.self) {
            _ = try GrowerBreederDraft(name: "Sensi Seeds", notes: notes, website: "")
        }
    }

    @Test func notesAreTrimmedAndAnEmptyDraftIsRecognised() throws {
        let draft = try GrowerBreederDraft(name: "Sensi Seeds", notes: "   ", website: "  ")

        #expect(draft.notes.isEmpty)
        #expect(draft.website == nil)
        #expect(draft.isEmpty)
    }

    @Test func anAddressWithoutASchemeIsReadAsHTTPS() throws {
        let draft = try GrowerBreederDraft(name: "Sensi Seeds", notes: "", website: "sensiseeds.com")

        let website = try #require(draft.website)
        #expect(website.hasPrefix("https://sensiseeds.com"))
        #expect(!draft.isEmpty)
    }

    @Test func aPlainHTTPAddressIsRejected() {
        #expect(
            throws: GrowerBreederError.self
        ) {
            _ = try GrowerBreederDraft(
                name: "Sensi Seeds",
                notes: "",
                website: "http://sensiseeds.com"
            )
        }
    }

    @Test func anAddressWithNoHostIsRejected() {
        #expect(GrowerBreederService.websiteURL(from: "not a url") == nil)
        #expect(GrowerBreederService.websiteURL(from: "https://") == nil)
        #expect(GrowerBreederService.websiteURL(from: "  ") == nil)
    }
}

@Suite(.serialized)
struct GrowerBreederMergeTests {
    @Test func withNoStoredNotesTheReferenceIsExactlyTheBundledProfiles() {
        let all = BreederLibrary.allProfiles()

        #expect(all.count == BreederLibrary.profiles.count)
        #expect(all.allSatisfy { !$0.hasYourNotes && !$0.isGrowerOnly })
    }

    @Test func notesAttachToTheBundledProfileByKey() throws {
        let record = GrowerBreeder(name: "  sensi   SEEDS ", notes: "Slow to root, steady in flower.")

        let all = BreederLibrary.allProfiles(stored: [record])
        let sensi = try #require(all.first { $0.name == "Sensi Seeds" })

        #expect(sensi.yourNotes == "Slow to root, steady in flower.")
        #expect(!sensi.isGrowerOnly)
        #expect(sensi.summary == BreederLibrary.profile(named: "Sensi Seeds")?.summary)
        #expect(all.filter { BreederLibrary.key(for: $0.name) == "sensi seeds" }.count == 1)
        #expect(all.count == BreederLibrary.profiles.count)
    }

    @Test func aGrowerOnlyBreederAppearsOnceAfterTheBundledOnes() throws {
        let record = GrowerBreeder(name: "Corner Closet Seeds", notes: "A local cut.")

        let all = BreederLibrary.allProfiles(stored: [record])
        let profile = try #require(all.last)

        #expect(profile.name == "Corner Closet Seeds")
        #expect(profile.isGrowerOnly)
        #expect(profile.yourNotes == "A local cut.")
        #expect(profile.source == BreederLibrary.yourNotesSource)
        #expect(all.count == BreederLibrary.profiles.count + 1)
    }

    @Test func aRecordWithNothingInItIsNotListed() {
        let empty = GrowerBreeder(name: "Empty Seeds", notes: "   ")

        let all = BreederLibrary.allProfiles(stored: [empty])

        #expect(!all.contains { $0.name == "Empty Seeds" })
    }

    @Test func duplicateRecordsForOneBreederCollapseToTheNewest() throws {
        let older = GrowerBreeder(
            name: "Sensi Seeds",
            notes: "First note",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = GrowerBreeder(
            name: "sensi seeds",
            notes: "Second note",
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let all = BreederLibrary.allProfiles(stored: [older, newer])
        let sensi = try #require(all.first { BreederLibrary.key(for: $0.name) == "sensi seeds" })

        #expect(sensi.yourNotes == "Second note")
        #expect(all.filter { BreederLibrary.key(for: $0.name) == "sensi seeds" }.count == 1)
    }

    @Test func aWebAddressBecomesATheLinkAndABundledLinkIsNotRepeated() throws {
        let record = GrowerBreeder(
            name: "Sensi Seeds",
            notes: "",
            website: "https://sensiseeds.com"
        )

        let all = BreederLibrary.allProfiles(stored: [record])
        let sensi = try #require(all.first { $0.name == "Sensi Seeds" })
        let addresses = sensi.links.map { $0.url.absoluteString.lowercased() }

        #expect(addresses.filter { $0.contains("sensiseeds.com") }.count == 1)
    }

    @Test func searchFindsYourOwnNotes() throws {
        let record = GrowerBreeder(name: "Corner Closet Seeds", notes: "Kept the mother in the shed.")

        let matches = BreederLibrary.profiles(matching: "shed", stored: [record])
        let profile = try #require(matches.first)

        #expect(profile.name == "Corner Closet Seeds")
    }

    @Test func profileLookupIgnoresCaseAccentsAndSpacing() {
        let record = GrowerBreeder(name: "Café   Seeds", notes: "Blueberry.")

        #expect(BreederLibrary.profile(named: "cafe seeds", stored: [record])?.hasYourNotes == true)
    }
}

@Suite(.serialized)
struct GrowerBreederStorageTests {
    @Test func savingWritesOneRecord() throws {
        let context = try breederContext()

        let record = try GrowerBreederService.save(
            name: " Corner Closet Seeds ",
            notes: " A local cut. ",
            website: "",
            existing: nil,
            in: context
        )

        let saved = try #require(record)
        #expect(saved.name == "Corner Closet Seeds")
        #expect(saved.notes == "A local cut.")
        #expect(DataInventory.counts(in: context)["GrowerBreeder"] == 1)
    }

    @Test func savingTheSameBreederAgainKeepsOneRecord() throws {
        let context = try breederContext()

        try GrowerBreederService.save(
            name: "Sensi Seeds",
            notes: "First",
            website: "",
            existing: nil,
            in: context
        )
        let second = try GrowerBreederService.save(
            name: "sensi seeds",
            notes: "Second",
            website: "",
            existing: nil,
            in: context
        )

        #expect(second?.notes == "Second")
        #expect(DataInventory.counts(in: context)["GrowerBreeder"] == 1)
    }

    @Test func aBundledBreederKeepsItsCanonicalName() throws {
        let context = try breederContext()

        let record = try GrowerBreederService.save(
            name: "sensiseeds",
            notes: "Note",
            website: "",
            existing: nil,
            in: context
        )

        // "sensiseeds" does not match "Sensi Seeds", so it is its own breeder.
        #expect(record?.name == "sensiseeds")

        let canonical = try GrowerBreederService.save(
            name: " sensi  seeds ",
            notes: "Steady",
            website: "",
            existing: nil,
            in: context
        )
        #expect(canonical?.name == "Sensi Seeds")
    }

    @Test func clearingNotesAndWebsiteRemovesTheRecord() throws {
        let context = try breederContext()
        let record = try GrowerBreederService.save(
            name: "Sensi Seeds",
            notes: "Some notes",
            website: "",
            existing: nil,
            in: context
        )

        let cleared = try GrowerBreederService.save(
            name: "Sensi Seeds",
            notes: "   ",
            website: "",
            existing: record,
            in: context
        )

        #expect(cleared == nil)
        #expect(DataInventory.counts(in: context)["GrowerBreeder"] == 0)
    }

    @Test func anInvalidSaveChangesNothing() throws {
        let context = try breederContext()

        #expect(throws: GrowerBreederError.self) {
            try GrowerBreederService.save(
                name: "",
                notes: "Something",
                website: "",
                existing: nil,
                in: context
            )
        }

        #expect(DataInventory.counts(in: context)["GrowerBreeder"] == 0)
    }

    @Test func deleteRemovesTheRecord() throws {
        let context = try breederContext()
        let record = try #require(
            try GrowerBreederService.save(
                name: "Corner Closet Seeds",
                notes: "A local cut.",
                website: "",
                existing: nil,
                in: context
            )
        )

        try GrowerBreederService.delete(record, in: context)

        #expect(DataInventory.counts(in: context)["GrowerBreeder"] == 0)
    }

    @Test func theModelIsInTheSchemaAndTheMigration() {
        #expect(DataInventory.modelNames.contains("GrowerBreeder"))
        #expect(DataInventory.label(for: "GrowerBreeder") != "GrowerBreeder")
        #expect(CultivationMigrationPlan.stages.count == 4)
        #expect(
            CultivationSchemaV5.models.contains { String(describing: $0) == "GrowerBreeder" }
        )
    }

    @Test func breederNotesAreExportedAndBackedUp() throws {
        let context = try breederContext()
        let record = GrowerBreeder(
            name: "Sensi Seeds",
            notes: "Steady in flower.",
            website: "https://sensiseeds.com"
        )
        context.insert(record)
        try context.save()

        let counts = DataInventory.counts(in: context)
        #expect(counts["GrowerBreeder"] == 1)

        let snapshot = ExportSnapshot(breeders: [record], counts: counts)

        let json = try ExportService.jsonData(snapshot: snapshot, options: ExportOptions())
        let root = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        let breeders = try #require(root["breeders"] as? [[String: Any]])

        #expect(breeders.count == 1)
        #expect(breeders.first?["name"] as? String == "Sensi Seeds")
        #expect(breeders.first?["notes"] as? String == "Steady in flower.")
        #expect(breeders.first?["website"] as? String == "https://sensiseeds.com")

        let manifest = try #require(root["manifest"] as? [String: Any])
        #expect((manifest["counts"] as? [String: Any])?["GrowerBreeder"] as? Int == 1)

        let backup = try ExportService.buildBackup(
            snapshot: snapshot,
            includeJournal: false,
            includePhotos: false,
            password: "correct-horse-battery"
        )
        let decoded = try ExportService.decodeBackup(backup, password: "correct-horse-battery")
        try BackupService.validate(decoded)
    }

    @Test func deleteAllRemovesBreederNotes() throws {
        let context = try breederContext()
        context.insert(GrowerBreeder(name: "Corner Closet Seeds", notes: "A local cut."))
        try context.save()

        let remaining = try DataInventory.deleteAll(in: context)

        #expect(remaining["GrowerBreeder"] == 0)
        #expect(DataInventory.total(of: remaining) == 0)
    }
}

private func breederContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: DataInventory.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    return ModelContext(container)
}
