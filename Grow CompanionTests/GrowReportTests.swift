//
//  GrowReportTests.swift
//  Grow CompanionTests
//
//  The report's required content: rule-pack provenance, verification duty,
//  allowed dispositions, journal exclusion and a readable PDF.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@MainActor
struct GrowReportTests {
    @Test func theReportCarriesComplianceProvenanceAndAllowedDispositions() throws {
        let fixture = try makeFixture()
        let data = GrowReportService.makeData(
            plants: fixture.plants,
            rooms: [fixture.room],
            profile: fixture.profile,
            journal: fixture.journal,
            rule: fixture.rule,
            warningThreshold: 0.8,
            unit: .metric,
            includeJournal: false
        )

        let titles = data.sections.map(\.title)
        #expect(titles.contains("Compliance estimate"))
        #expect(titles.contains("Stage timeline"))
        #expect(titles.contains("Feeding and environment summary"))
        #expect(titles.contains("Training"))
        #expect(titles.contains("Treatments"))
        #expect(titles.contains("Scouting checks"))
        #expect(titles.contains("Harvest"))
        #expect(titles.contains("Scope and journal"))

        let text = fixture.text(of: data)
        #expect(text.contains(RulePack.version))
        #expect(text.contains(RulePack.displayDate(RulePack.verifiedOn)))
        #expect(text.contains(data.verificationDuty))
        #expect(text.contains("Retained"))
        #expect(text.contains("Destroyed"))
        #expect(text.contains("no sale, gift, transfer"))
        #expect(!text.contains("Sold"))
        #expect(!text.contains("Secret garden note"))
        #expect(text.contains("does not have one"))
    }

    @Test func journalTextIsIncludedOnlyWhenChosen() throws {
        let fixture = try makeFixture()
        let without = GrowReportService.makeData(
            plants: fixture.plants,
            rooms: [fixture.room],
            profile: fixture.profile,
            journal: fixture.journal,
            rule: fixture.rule,
            warningThreshold: 0.8,
            unit: .metric,
            includeJournal: false
        )
        let with = GrowReportService.makeData(
            plants: fixture.plants,
            rooms: [fixture.room],
            profile: fixture.profile,
            journal: fixture.journal,
            rule: fixture.rule,
            warningThreshold: 0.8,
            unit: .metric,
            includeJournal: true
        )

        #expect(!fixture.text(of: without).contains("Secret garden note"))
        #expect(fixture.text(of: with).contains("Secret garden note"))
    }

    @Test func thePDFIsReadableAndTheFileNameIsNeutral() throws {
        let fixture = try makeFixture()
        let data = GrowReportService.makeData(
            plants: fixture.plants,
            rooms: [fixture.room],
            profile: fixture.profile,
            journal: fixture.journal,
            rule: fixture.rule,
            warningThreshold: 0.8,
            unit: .metric,
            includeJournal: true
        )

        let pdf = GrowReportRenderer.pdf(from: data)
        #expect(pdf.count > 500)
        #expect(pdf.starts(with: Data("%PDF".utf8)))

        let name = GrowReportRenderer.fileName(for: data.generatedAt)
        #expect(name.hasPrefix("Grow-Report-"))
        #expect(name.hasSuffix(".pdf"))
        #expect(!name.contains("One"))
        #expect(!name.contains("Tent"))
        #expect(!name.contains("Blue Dream"))

        let url = try GrowReportRenderer.writeTemporaryFile(pdf: pdf, fileName: name)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: url).count == pdf.count)
    }

    // MARK: Fixture

    private struct Fixture {
        let plants: [Plant]
        let room: Room
        let profile: GrowProfile
        let rule: JurisdictionRule
        let journal: [JournalEntry]

        func text(of data: GrowReportData) -> String {
            data.sections.flatMap { [$0.title] + $0.lines }.joined(separator: "\n")
        }
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let profile = GrowProfile(
            stateCode: "CA",
            stateName: "California",
            onboardingCompletedAt: Date()
        )
        context.insert(profile)

        let room = Room(name: "Tent", lightWatts: 300)
        context.insert(room)

        let plant = Plant(
            name: "One",
            strainName: "Blue Dream",
            stage: .flower,
            room: room
        )
        plant.wetWeightGrams = 100
        plant.dryWeightGrams = 25
        plant.harvestDisposition = .retained
        plant.harvestedAt = Date()
        context.insert(plant)

        let destroyed = Plant(name: "Two", stage: .storage, room: room)
        destroyed.dryWeightGrams = 10
        destroyed.harvestDisposition = .destroyed
        context.insert(destroyed)

        context.insert(StageEvent(stage: .veg, date: Date().addingTimeInterval(-40 * 86_400), plant: plant))
        context.insert(StageEvent(stage: .flower, date: Date().addingTimeInterval(-30 * 86_400), plant: plant))
        context.insert(FeedEvent(date: Date().addingTimeInterval(-2 * 86_400), kind: .water, volumeLiters: 2, room: room))
        context.insert(EnvironmentReading(date: Date().addingTimeInterval(-86_400), temperatureC: 24, humidityPercent: 55, room: room))
        context.insert(TrainingSession(method: .topping, date: Date().addingTimeInterval(-20 * 86_400), plant: plant))
        context.insert(Treatment(productName: "Neem", date: Date().addingTimeInterval(-10 * 86_400), plant: plant))
        context.insert(ScoutingCheck(date: Date().addingTimeInterval(-9 * 86_400), findings: [.pests], plant: plant))

        let journal = JournalEntry(
            kind: .note,
            text: "Secret garden note",
            createdAt: Date().addingTimeInterval(-3 * 86_400),
            plant: plant
        )
        context.insert(journal)
        try context.save()

        let rule = try #require(RulePack.rule(forStateCode: "CA"))
        return Fixture(
            plants: [plant, destroyed],
            room: room,
            profile: profile,
            rule: rule,
            journal: [journal]
        )
    }
}
