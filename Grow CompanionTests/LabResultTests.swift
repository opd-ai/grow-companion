//
//  LabResultTests.swift
//  Grow CompanionTests
//
//  A lab report is the grower's own copy of a report they hold: it needs their
//  confirmation, it keeps the figures exactly as printed, and it travels with
//  the plant through export, backup, restore and delete.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct LabResultTests {
    private func labContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func draft(_ analytes: [LabAnalyte], confirmed: Bool = true, date: Date = Date()) -> LabResultDraft {
        LabResultDraft(
            reportDate: date,
            labName: "  North Lab  ",
            notes: "  Sample from the top cola  ",
            analytes: analytes,
            userConfirmed: confirmed
        )
    }

    @Test func savingRequiresTheGrowersConfirmation() {
        let figures = [LabAnalyte(name: "Total THC", value: "18.4", unit: "%")]

        #expect(throws: LabResultError.self) {
            try LabResultService.validated(draft(figures, confirmed: false))
        }
    }

    @Test func aReportNeedsAtLeastOneCompleteFigure() {
        #expect(throws: LabResultError.self) {
            try LabResultService.validated(draft([]))
        }

        // Rows the grower started and left empty are ignored, not saved.
        let half = [LabAnalyte(name: "Total THC", value: ""), LabAnalyte(name: "", value: "")]
        #expect(throws: LabResultError.self) {
            try LabResultService.validated(draft(half))
        }
    }

    @Test func valuesAreKeptAsTheReportPrintedThem() throws {
        let figures = [
            LabAnalyte(name: " Total THC ", value: " 18.4 ", unit: " % ", flagged: false),
            LabAnalyte(name: "Mould", value: "Not detected", unit: "", flagged: true),
            LabAnalyte(name: "", value: "", unit: "")
        ]

        let valid = try LabResultService.validated(draft(figures))

        #expect(valid.userConfirmed)
        #expect(valid.labName == "North Lab")
        #expect(valid.notes == "Sample from the top cola")
        #expect(valid.analytes.count == 2)
        #expect(valid.analytes[0].value == "18.4")
        #expect(valid.analytes[0].unit == "%")
        #expect(valid.analytes[1].value == "Not detected")
        #expect(valid.analytes[1].flagged)
    }

    @Test func aReportCannotBeDatedInTheFuture() {
        let figures = [LabAnalyte(name: "Total THC", value: "18.4", unit: "%")]
        let later = Date().addingTimeInterval(86_400)

        #expect(throws: LabResultError.self) {
            try LabResultService.validated(draft(figures, date: later))
        }
    }

    @Test func theFigureCountIsCapped() {
        let many = (0...LabResultService.maximumAnalytes).map {
            LabAnalyte(name: "Figure \($0)", value: "1")
        }

        #expect(throws: LabResultError.self) {
            try LabResultService.validated(draft(many))
        }
    }

    @Test func savingWritesTheReportOntoThePlant() throws {
        let context = try labContext()
        let plant = Plant(name: "Blue Dream", stage: .cure)
        context.insert(plant)
        try context.save()

        let result = try LabResultService.save(
            draft([LabAnalyte(name: "Total THC", value: "18.4", unit: "%")]),
            existing: nil,
            for: plant,
            in: context
        )

        #expect(plant.labResults.count == 1)
        #expect(result.userConfirmed)
        #expect(result.displayName == "North Lab")
        #expect(try context.fetchCount(FetchDescriptor<LabResult>()) == 1)
    }

    @Test func editingASavedReportUpdatesTheSameRecord() throws {
        let context = try labContext()
        let plant = Plant(name: "One", stage: .cure)
        context.insert(plant)
        try context.save()

        let result = try LabResultService.save(
            draft([LabAnalyte(name: "Total THC", value: "18.4")]),
            existing: nil,
            for: plant,
            in: context
        )
        let previousCount = try context.fetchCount(FetchDescriptor<LabResult>())

        let edited = try LabResultService.save(
            draft([LabAnalyte(name: "Total THC", value: "19.1", unit: "%")]),
            existing: result,
            for: plant,
            in: context
        )

        #expect(edited.persistentModelID == result.persistentModelID)
        #expect(edited.analytes.first?.value == "19.1")
        #expect(try context.fetchCount(FetchDescriptor<LabResult>()) == previousCount)
    }

    @Test func deletingAReportRemovesItFromThePlant() throws {
        let context = try labContext()
        let plant = Plant(name: "One", stage: .cure)
        context.insert(plant)
        try context.save()

        let result = try LabResultService.save(
            draft([LabAnalyte(name: "Total THC", value: "18.4")]),
            existing: nil,
            for: plant,
            in: context
        )

        try LabResultService.delete(result, in: context)

        #expect(try context.fetchCount(FetchDescriptor<LabResult>()) == 0)
        #expect(plant.labResults.isEmpty)
    }

    @Test func theFiguresRoundTripThroughTheStoredValue() throws {
        let result = LabResult()
        let figures = [
            LabAnalyte(name: "Total THC", value: "18.4", unit: "%", flagged: false),
            LabAnalyte(name: "Mould", value: "Not detected", unit: "", flagged: true)
        ]

        result.analytes = figures

        #expect(result.analytes == figures)
        #expect(result.flaggedAnalytes.count == 1)
        #expect(result.flaggedAnalytes.first?.name == "Mould")
    }

    @Test func anUnnamedReportStillHasATitle() {
        #expect(LabResult().displayName == "Lab report")
        #expect(LabResult(labName: "  North Lab  ").displayName == "North Lab")
    }

    @Test func reportsAreListedNewestFirst() throws {
        let context = try labContext()
        let plant = Plant(name: "One", stage: .cure)
        context.insert(plant)

        let older = LabResult(reportDate: Date().addingTimeInterval(-86_400), plant: plant)
        let newer = LabResult(reportDate: Date(), plant: plant)
        context.insert(older)
        context.insert(newer)
        try context.save()

        let sorted = LabResultService.sorted(plant.labResults)
        #expect(sorted.first?.persistentModelID == newer.persistentModelID)
    }

    @Test func theStoredTypeIsInEveryDataControl() {
        let names = DataInventory.modelNames

        #expect(names.contains("LabResult"))
        #expect(DataInventory.probes.map(\.name).contains("LabResult"))
        #expect(ExportService.exportedModelNames.contains("LabResult"))
        #expect(DataInventory.label(for: "LabResult") != "LabResult")
    }

    @Test func aReportTravelsThroughTheBackupDocument() throws {
        let context = try labContext()
        let plant = Plant(name: "Blue Dream", stage: .cure)
        context.insert(plant)
        try context.save()

        try LabResultService.save(
            draft([LabAnalyte(name: "Total THC", value: "18.4", unit: "%", flagged: true)]),
            existing: nil,
            for: plant,
            in: context
        )

        let snapshot = ExportSnapshot(
            plants: [plant],
            labResults: plant.labResults,
            counts: DataInventory.counts(in: context)
        )
        let data = try ExportService.buildBackup(
            snapshot: snapshot,
            includeJournal: false,
            includePhotos: false,
            password: "correct-horse-battery"
        )

        let root = try ExportService.decodeBackup(data, password: "correct-horse-battery")
        let section = try #require(root["labResults"] as? [[String: Any]])

        #expect(section.count == 1)
        #expect(section.first?["lab"] as? String == "North Lab")
        #expect(section.first?["plant"] as? String == "Blue Dream")

        let figures = try #require(section.first?["analytes"] as? [[String: Any]])
        #expect(figures.count == 1)
        #expect(figures.first?["name"] as? String == "Total THC")
        #expect(figures.first?["value"] as? String == "18.4")
        #expect(figures.first?["flagged"] as? Bool == true)

        try BackupService.validate(root)
    }
}
