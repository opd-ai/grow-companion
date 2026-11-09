//
//  DataSafetyTests.swift
//  Grow CompanionTests
//
//  Coverage and backup-format tests for the local data controls. The coverage
//  tests fail when a model is added to the schema but not to export or delete.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

struct DataCoverageTests {
    @Test func schemaModelNamesAreUnique() {
        let names = DataInventory.modelNames
        #expect(names.count == Set(names).count)
        #expect(!names.isEmpty)
    }

    @Test func deleteCoversEveryModelInTheSchema() {
        let deletable = Set(DataInventory.probes.map(\.name))
        let stored = Set(DataInventory.modelNames)
        #expect(deletable == stored)
    }

    @Test func exportCoversEveryModelInTheSchema() {
        let exported = Set(ExportService.exportedModelNames)
        let stored = Set(DataInventory.modelNames)
        #expect(exported == stored)
    }

    @Test func everyModelHasALabel() {
        for name in DataInventory.modelNames {
            #expect(DataInventory.label(for: name) != name)
        }
    }
}

struct DataDeletionTests {
    @Test func deleteAllLeavesNoRecords() throws {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let room = Room(name: "Tent")
        context.insert(room)
        let plant = Plant(name: "One", room: room)
        context.insert(plant)
        context.insert(Treatment(productName: "Neem", plant: plant))
        context.insert(TrainingSession(method: .topping, plant: plant))
        context.insert(ScoutingCheck(findings: [.pests], plant: plant))
        try context.save()

        let before = DataInventory.counts(in: context)
        #expect(before["Plant"] == 1)
        #expect(before["Treatment"] == 1)
        #expect(before["TrainingSession"] == 1)
        #expect(before["ScoutingCheck"] == 1)

        let remaining = try DataInventory.deleteAll(in: context)
        #expect(DataInventory.total(of: remaining) == 0)
    }

    @Test func emptyStoreCountsAsAZeroManifest() throws {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        let counts = DataInventory.counts(in: context)
        #expect(!counts.isEmpty)
        #expect(DataInventory.total(of: counts) == 0)
        #expect(DataInventory.nonEmpty(from: counts).isEmpty)
    }
}

struct DataControlPreferenceTests {
    @Test func readingProgressIsClearedByDeleteAll() {
        #expect(SettingsKey.all.contains(SettingsKey.educationCompletedLessons))
        #expect(SettingsKey.all.contains(SettingsKey.appLanguage))
    }
}

struct BackupFormatTests {
    @Test func v2BackupRoundTripsWithAManifest() throws {
        let snapshot = ExportSnapshot(counts: ["Room": 0, "Plant": 0])
        let data = try ExportService.buildBackup(
            snapshot: snapshot,
            includeJournal: false,
            includePhotos: false,
            password: "correct-horse-battery"
        )

        let root = try ExportService.decodeBackup(data, password: "correct-horse-battery")
        #expect(root["backupVersion"] as? Int == 2)
        #expect(root["formatVersion"] as? Int == 2)

        let manifest = root["manifest"] as? [String: Any]
        #expect(manifest != nil)
        #expect((manifest?["counts"] as? [String: Any])?["Plant"] as? Int == 0)

        let summary = try ExportService.summarize(root)
        #expect(summary.version == 2)
        #expect(summary.includesPhotos == false)
    }

    @Test func v1BackupIsStillReadable() throws {
        let document: [String: Any] = ["backupVersion": 1, "rooms": [], "plants": []]
        let data = try ExportService.encodeBackup(document, password: "legacy-password", formatVersion: 1)
        let root = try ExportService.decodeBackup(data, password: "legacy-password")
        #expect(root["backupVersion"] as? Int == 1)
    }

    @Test func wrongPasswordIsRejected() throws {
        let snapshot = ExportSnapshot(counts: [:])
        let data = try ExportService.buildBackup(
            snapshot: snapshot,
            includeJournal: false,
            includePhotos: false,
            password: "correct-horse-battery"
        )
        #expect(throws: ExportServiceError.self) {
            try ExportService.decodeBackup(data, password: "not-the-password")
        }
    }

    @Test func tamperedArchiveIsRejected() throws {
        let snapshot = ExportSnapshot(counts: [:])
        var data = try ExportService.buildBackup(
            snapshot: snapshot,
            includeJournal: false,
            includePhotos: false,
            password: "correct-horse-battery"
        )
        let last = data.index(before: data.endIndex)
        data[last] ^= 0xFF

        #expect(throws: ExportServiceError.self) {
            try ExportService.decodeBackup(data, password: "correct-horse-battery")
        }
    }

    @Test func newerBackupVersionFailsClosed() {
        var data = Data("GROWBACK9".utf8)
        data.append(Data(repeating: 0, count: 64))

        #expect(throws: ExportServiceError.self) {
            try ExportService.decodeBackup(data, password: "anything")
        }
    }
}

struct BackupValidationTests {
    @Test func manifestThatDisagreesWithTheFileIsRejected() {
        let document: [String: Any] = [
            "backupVersion": 2,
            "rooms": [],
            "plants": [],
            "manifest": ["counts": ["Room": 3]]
        ]
        #expect(throws: ExportServiceError.self) {
            try BackupService.validate(document)
        }
    }

    @Test func minimalLegacyDocumentIsAccepted() throws {
        let document: [String: Any] = ["backupVersion": 1, "rooms": [], "plants": []]
        try BackupService.validate(document)
    }

    @Test func sectionThatIsNotAListIsRejected() {
        let document: [String: Any] = [
            "backupVersion": 2,
            "rooms": [],
            "plants": [],
            "treatments": "not-a-list"
        ]
        #expect(throws: ExportServiceError.self) {
            try BackupService.validate(document)
        }
    }

    @Test func documentFromTheFutureIsRejected() {
        let document: [String: Any] = ["backupVersion": 99, "rooms": [], "plants": []]
        #expect(throws: ExportServiceError.self) {
            try BackupService.validate(document)
        }
    }
}
