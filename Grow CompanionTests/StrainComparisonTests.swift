//
//  StrainComparisonTests.swift
//  Grow CompanionTests
//
//  Comparing cultivars uses the grower's own harvested cycles: the averages, the
//  sample sizes that travel with them, the gaps that stay gaps, and the text
//  equivalent of the bars.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct StrainComparisonTests {
    private func comparisonContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func day(_ offset: Int, from start: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: start) ?? start
    }

    @discardableResult
    private func finishedPlant(
        _ name: String,
        strain: Strain? = nil,
        strainName: String = "",
        flowerDay: Int = 0,
        harvestDay: Int = 63,
        dry: Double? = nil,
        rating: Int? = nil,
        in context: ModelContext
    ) -> Plant {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let plant = Plant(
            name: name,
            strainName: strainName,
            stage: .harvest,
            plantedAt: start,
            strain: strain
        )
        plant.harvestedAt = day(harvestDay, from: start)
        plant.dryWeightGrams = dry
        plant.rating = rating
        context.insert(plant)

        let flower = StageEvent(stage: .flower, date: day(flowerDay, from: start), plant: plant)
        context.insert(flower)
        return plant
    }

    @discardableResult
    private func growingPlant(
        _ name: String,
        strain: Strain? = nil,
        in context: ModelContext
    ) -> Plant {
        let plant = Plant(name: name, stage: .flower, strain: strain)
        context.insert(plant)
        return plant
    }

    private func strain(_ name: String, weeks: Int = 9, in context: ModelContext) -> Strain {
        let strain = Strain(name: name, expectedFloweringWeeks: weeks)
        context.insert(strain)
        return strain
    }

    // MARK: Grouping

    @Test func onlyPlantsWithACultivarAreCompared() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        finishedPlant("A", strain: blue, in: context)
        context.insert(Plant(name: "Mystery"))

        let samples = StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>()))

        #expect(samples.count == 1)
        #expect(samples.first?.name == "Blue Dream")
    }

    @Test func namesThatDifferOnlyInCaseAndAccentsAreOneCultivar() throws {
        let context = try comparisonContext()
        finishedPlant("A", strainName: "Jamaican Pearl", dry: 90, in: context)
        finishedPlant("B", strainName: "  jamaican pearl  ", dry: 110, in: context)

        let samples = StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>()))

        #expect(samples.count == 1)
        #expect(samples.first?.cycles == 2)
        #expect(samples.first?.yieldSamples == 2)
        #expect(samples.first?.dryYieldGrams == 100)
    }

    @Test func growingPlantsAreCountedButNotAveraged() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        finishedPlant("A", strain: blue, dry: 100, in: context)
        growingPlant("B", strain: blue, in: context)
        growingPlant("C", strain: blue, in: context)

        let sample = try #require(StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>())).first)

        #expect(sample.cycles == 1)
        #expect(sample.inProgress == 2)
        #expect(sample.dryYieldGrams == 100)
        #expect(sample.inProgressText?.contains("2") == true)
    }

    // MARK: Averages

    @Test func theAveragesCoverEveryFinishedCycleThatRecordedTheFigure() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        finishedPlant("A", strain: blue, flowerDay: 0, harvestDay: 63, dry: 100, rating: 4, in: context)
        finishedPlant("B", strain: blue, flowerDay: 0, harvestDay: 70, dry: 120, rating: nil, in: context)

        let sample = try #require(StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>())).first)

        #expect(sample.cycles == 2)
        #expect(sample.floweringDays == 67)
        #expect(sample.floweringSamples == 2)
        #expect(sample.dryYieldGrams == 110)
        #expect(sample.yieldSamples == 2)
        #expect(sample.rating == 4)
        #expect(sample.ratingSamples == 1)
    }

    @Test func aMissingFigureStaysMissing() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        finishedPlant("A", strain: blue, dry: nil, rating: nil, in: context)

        let sample = try #require(StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>())).first)

        #expect(sample.cycles == 1)
        #expect(sample.dryYieldGrams == nil)
        #expect(sample.rating == nil)
        #expect(sample.floweringDays != nil)
    }

    @Test func aFinishedPlantWithoutAFlowerEventHasNoFloweringFigure() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        let plant = Plant(name: "A", stage: .harvest, strain: blue)
        plant.harvestedAt = Date()
        context.insert(plant)

        let sample = try #require(StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>())).first)

        #expect(sample.cycles == 1)
        #expect(sample.floweringDays == nil)
        #expect(sample.floweringSamples == 0)
    }

    @Test func theCultivarsWithTheMostCyclesComeFirst() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        let diesel = strain("Sour Diesel", in: context)
        finishedPlant("A", strain: blue, in: context)
        finishedPlant("B", strain: blue, in: context)
        finishedPlant("C", strain: diesel, in: context)

        let samples = StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>()))

        #expect(samples.map(\.name) == ["Blue Dream", "Sour Diesel"])
        #expect(samples.first?.cycles == 2)
        #expect(samples.last?.cycles == 1)
    }

    // MARK: Measures and tables

    @Test func aChartOnlyDrawsTheCultivarsWithAValue() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        let diesel = strain("Sour Diesel", in: context)
        finishedPlant("A", strain: blue, dry: 100, in: context)
        finishedPlant("B", strain: diesel, dry: nil, in: context)

        let samples = StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>()))

        #expect(StrainComparison.samples(samples, with: .dryYieldGrams).map(\.name) == ["Blue Dream"])
        #expect(StrainComparison.samples(samples, with: .floweringDays).count == 2)
    }

    @Test func theMeasureFormatsInTheChosenUnits() throws {
        let restore = Format.locale
        Format.locale = Locale(identifier: "en_US")
        defer { Format.locale = restore }

        #expect(CultivarMetric.floweringDays.display(63, unit: .metric) == Format.dayCount(63))
        #expect(CultivarMetric.dryYieldGrams.display(100, unit: .metric) == "100 g")
        #expect(CultivarMetric.dryYieldGrams.display(100, unit: .imperial) == "3.5 oz")
        #expect(CultivarMetric.rating.display(4.2, unit: .metric) == "4.2 / 5")
    }

    @Test func theTableListsTheSameValuesAsTheBars() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        let diesel = strain("Sour Diesel", in: context)
        finishedPlant("A", strain: blue, dry: 100, in: context)
        finishedPlant("B", strain: diesel, dry: 90, in: context)

        let samples = StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>()))
        let table = ChartTables.cultivarComparison(
            samples,
            metric: .dryYieldGrams,
            unit: .metric,
            summary: "Two cultivars"
        )

        #expect(table.rows.count == 2)
        #expect(table.rows.map(\.label) == ["Blue Dream", "Sour Diesel"])
        #expect(table.rows.first?.value == "100 g")
        #expect(table.rows.allSatisfy { !$0.isFlagged })
    }

    @Test func oneCultivarIsNotEnoughToCompare() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        finishedPlant("A", strain: blue, in: context)

        let single = StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>()))
        #expect(!StrainComparison.hasEnoughToCompare(single))

        finishedPlant("B", strain: strain("Sour Diesel", in: context), in: context)
        let pair = StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>()))
        #expect(StrainComparison.hasEnoughToCompare(pair))
    }

    @Test func oneCycleIsLabelledAsASingleRun() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        finishedPlant("A", strain: blue, in: context)
        growingPlant("B", strain: blue, in: context)

        let sample = try #require(StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>())).first)

        #expect(sample.isSingleCycle)
        #expect(sample.sampleText.contains("1"))
        #expect(sample.inProgressText?.contains("1") == true)
        #expect(StrainComparison.summary(for: sample).contains("·"))
    }

    @Test func aSampleKnowsHowMuchItRestsOn() throws {
        let context = try comparisonContext()
        let blue = strain("Blue Dream", in: context)
        finishedPlant("A", strain: blue, in: context)
        finishedPlant("B", strain: blue, in: context)

        let sample = try #require(StrainComparison.samples(from: try context.fetch(FetchDescriptor<Plant>())).first)

        #expect(!sample.isSingleCycle)
        #expect(sample.sampleText.contains("2"))
        #expect(sample.inProgressText == nil)
        #expect(!StrainComparison.summary(for: sample).isEmpty)
    }
}
