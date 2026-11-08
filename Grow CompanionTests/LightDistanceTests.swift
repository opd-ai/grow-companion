//
//  LightDistanceTests.swift
//  Grow CompanionTests
//
//  The light-distance guidance: the cited bands per fixture and stage, the
//  grower's own target, the status of a reading, the re-measure rules and the
//  room fields they are read from.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

// MARK: - Bands

@Suite(.serialized)
struct LightDistanceBandTests {
    private func band(_ stage: PlantStage, _ fixture: LightFixtureType) -> ClosedRange<Double>? {
        LightDistanceService.band(for: stage, fixture: fixture)
    }

    private func close(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 1e-9
    }

    @Test func floweringUsesTheCitedFixtureBand() throws {
        let advice = try #require(LightDistanceService.advice(for: .flower, fixture: .led))

        #expect(advice.isUserSet == false)
        #expect(close(advice.range.lowerBound, 0.30))
        #expect(close(advice.range.upperBound, 0.60))
        #expect(advice.summary == LightFixtureType.led.guidanceSource)
    }

    @Test func seedAndCloneReadFartherThanTheBaseBand() throws {
        let seed = try #require(band(.seed, .led))
        let clone = try #require(band(.clone, .led))

        #expect(close(seed.lowerBound, 0.60 * 0.95))
        #expect(close(seed.upperBound, 0.60 * 1.35))
        #expect(seed == clone)
        #expect(seed.lowerBound > 0.30)
    }

    @Test func vegetativeSitsAboveTheBaseBand() throws {
        let veg = try #require(band(.veg, .led))

        #expect(close(veg.lowerBound, 0.30 * 1.10))
        #expect(close(veg.upperBound, 0.60 * 1.15))
    }

    @Test func aFinishStageKeepsTheFloweringBand() throws {
        let flowering = try #require(band(.flower, .hps))

        #expect(band(.harvest, .hps) == flowering)
        #expect(band(.cure, .hps) == flowering)
        #expect(band(.storage, .hps) == flowering)
    }

    @Test func aFixtureWithNoCitedBandHasNoTarget() {
        #expect(LightDistanceService.band(for: .veg, fixture: .other) == nil)
        #expect(LightDistanceService.advice(for: .flower, fixture: .other) == nil)
    }

    @Test func aGrowerTargetReplacesEveryStage() throws {
        let target: ClosedRange<Double> = 0.25...0.45

        for stage in PlantStage.allCases {
            let advice = try #require(
                LightDistanceService.advice(for: stage, fixture: .led, userSetMeters: target)
            )
            #expect(advice.isUserSet)
            #expect(advice.range == target)
        }
    }

    @Test func aGrowerTargetWorksForAFixtureWithNoCitedBand() throws {
        let advice = try #require(
            LightDistanceService.advice(for: .veg, fixture: .other, userSetMeters: 0.20...0.40)
        )

        #expect(advice.isUserSet)
        #expect(advice.range == 0.20...0.40)
    }

    @Test func anInvertedOrTinyGrowerTargetIsRejected() {
        #expect(LightDistanceService.advice(for: .veg, fixture: .led, userSetMeters: 0.60...0.30) == nil)
        #expect(LightDistanceService.advice(for: .veg, fixture: .led, userSetMeters: 0.0...0.0) == nil)
    }
}

// MARK: - Status

@Suite(.serialized)
struct LightDistanceStatusTests {
    private var target: LightDistanceAdvice {
        LightDistanceAdvice(
            range: 0.30...0.60,
            isUserSet: false,
            summary: "Test",
            detail: "Test"
        )
    }

    @Test func aReadingInsideTheBandIsInside() {
        #expect(LightDistanceService.status(distance: 0.45, target: target) == .inside)
    }

    @Test func theBandEndsCountAsInside() {
        #expect(LightDistanceService.status(distance: 0.30, target: target) == .inside)
        #expect(LightDistanceService.status(distance: 0.60, target: target) == .inside)
    }

    @Test func aReadingBelowTheBandIsTooClose() {
        #expect(LightDistanceService.status(distance: 0.15, target: target) == .closer)
    }

    @Test func aReadingAboveTheBandIsTooFar() {
        #expect(LightDistanceService.status(distance: 1.20, target: target) == .over)
    }

    @Test func aMissingReadingOrTargetHasNoStatus() {
        #expect(LightDistanceService.status(distance: nil, target: target) == .noTarget)
        #expect(LightDistanceService.status(distance: 0.45, target: nil) == .noTarget)
        #expect(LightDistanceService.status(distance: 0, target: target) == .noTarget)
    }
}

// MARK: - Re-measure

@Suite(.serialized)
struct LightDistanceReMeasureTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func daysAgo(_ days: Int) -> Date {
        now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
    }

    @Test func aRoomWithNoMeasurementIsAskedForOne() {
        let reason = LightDistanceService.reMeasureReason(
            measuredMeters: nil,
            measuredAt: nil,
            measuredStage: nil,
            currentStage: .veg,
            trainingDates: [],
            now: now
        )

        #expect(reason == .neverMeasured)
    }

    @Test func aReadingWithoutADateIsTreatedAsMissing() {
        let reason = LightDistanceService.reMeasureReason(
            measuredMeters: 0.45,
            measuredAt: nil,
            measuredStage: nil,
            currentStage: .veg,
            trainingDates: [],
            now: now
        )

        #expect(reason == .neverMeasured)
    }

    @Test func aStageChangeAsksForANewMeasurement() {
        let reason = LightDistanceService.reMeasureReason(
            measuredMeters: 0.45,
            measuredAt: daysAgo(2),
            measuredStage: .veg,
            currentStage: .flower,
            trainingDates: [],
            now: now
        )

        #expect(reason == .stageChanged(from: .veg, to: .flower))
    }

    @Test func trainingAfterTheReadingAsksForANewMeasurement() {
        let reason = LightDistanceService.reMeasureReason(
            measuredMeters: 0.45,
            measuredAt: daysAgo(4),
            measuredStage: .flower,
            currentStage: .flower,
            trainingDates: [daysAgo(10), daysAgo(2)],
            now: now
        )

        #expect(reason == .trained(daysAgo: 4))
    }

    @Test func trainingBeforeTheReadingIsIgnored() {
        let reason = LightDistanceService.reMeasureReason(
            measuredMeters: 0.45,
            measuredAt: daysAgo(2),
            measuredStage: .flower,
            currentStage: .flower,
            trainingDates: [daysAgo(10), daysAgo(6)],
            now: now
        )

        #expect(reason == nil)
    }

    @Test func anOldReadingIsStale() {
        let reason = LightDistanceService.reMeasureReason(
            measuredMeters: 0.45,
            measuredAt: daysAgo(20),
            measuredStage: .flower,
            currentStage: .flower,
            trainingDates: [],
            now: now
        )

        #expect(reason == .stale(days: 20))
    }

    @Test func aRecentReadingWithNothingChangedNeedsNoPrompt() {
        let reason = LightDistanceService.reMeasureReason(
            measuredMeters: 0.45,
            measuredAt: daysAgo(3),
            measuredStage: .flower,
            currentStage: .flower,
            trainingDates: [],
            now: now
        )

        #expect(reason == nil)
    }

    @Test func aStageChangeOutranksTraining() {
        let reason = LightDistanceService.reMeasureReason(
            measuredMeters: 0.45,
            measuredAt: daysAgo(20),
            measuredStage: .veg,
            currentStage: .flower,
            trainingDates: [daysAgo(1)],
            now: now
        )

        #expect(reason == .stageChanged(from: .veg, to: .flower))
    }

    @Test func aRoomWithoutAPlantHasNoStageChangePrompt() {
        let reason = LightDistanceService.reMeasureReason(
            measuredMeters: 0.45,
            measuredAt: daysAgo(1),
            measuredStage: .veg,
            currentStage: nil,
            trainingDates: [],
            now: now
        )

        #expect(reason == nil)
    }

    @Test func everyReasonHasItsOwnCopy() {
        let reasons: [LightDistanceReason] = [
            .neverMeasured,
            .stageChanged(from: .veg, to: .flower),
            .trained(daysAgo: 3),
            .stale(days: 30)
        ]

        for reason in reasons {
            #expect(!LightDistanceService.reMeasureTitle(reason).isEmpty)
            #expect(!LightDistanceService.reMeasureDetail(reason).isEmpty)
        }

        #expect(LightDistanceService.reMeasureTitle(.stageChanged(from: .veg, to: .flower))
            != LightDistanceService.reMeasureTitle(.trained(daysAgo: 3)))
    }
}

// MARK: - Units

@Suite(.serialized)
struct LightDistanceUnitTests {
    @Test func metricEntryIsCentimetres() throws {
        let meters = try #require(Format.meters(fromEntry: "45", unit: .metric))
        #expect(abs(meters - 0.45) < 1e-9)
    }

    @Test func aDecimalCommaIsAccepted() throws {
        let meters = try #require(Format.meters(fromEntry: "45,5", unit: .metric))
        #expect(abs(meters - 0.455) < 1e-9)
    }

    @Test func imperialEntryIsInches() throws {
        let meters = try #require(Format.meters(fromEntry: "18", unit: .imperial))
        #expect(abs(meters - 0.4572) < 1e-9)
    }

    @Test func implausibleEntryIsRejected() {
        #expect(Format.meters(fromEntry: "", unit: .metric) == nil)
        #expect(Format.meters(fromEntry: "abc", unit: .metric) == nil)
        #expect(Format.meters(fromEntry: "0", unit: .metric) == nil)
        #expect(Format.meters(fromEntry: "-40", unit: .metric) == nil)
        #expect(Format.meters(fromEntry: "5000", unit: .metric) == nil)
    }

    @Test func displayUsesTheGrowersUnit() {
        let metric = Format.distance(0.45, unit: .metric)
        let imperial = Format.distance(0.3048, unit: .imperial)

        #expect(metric.contains("45"))
        #expect(metric.contains("cm"))
        #expect(imperial.contains("12"))
        #expect(imperial.contains("in"))
        #expect(Format.distanceUnit(.metric) == "cm")
        #expect(Format.distanceUnit(.imperial) == "in")
    }

    @Test func aRangeReadsAsOneBand() {
        let text = Format.distanceRange(0.30...0.60, unit: .metric)

        #expect(text.contains("30"))
        #expect(text.contains("60"))
        #expect(!Format.distanceEntryText(0.45, unit: .metric).contains("cm"))
    }
}

// MARK: - The room record

@Suite(.serialized)
struct LightDistanceRoomTests {
    @Test func aRoomWithNoCitedBandAndNoTargetHasNoAdvice() {
        let room = Room(name: "Tent", lightFixture: .other)

        #expect(room.lightDistanceAdvice == nil)
        #expect(room.lightDistanceReason == .neverMeasured)
    }

    @Test func theRoomStageChoosesTheBand() throws {
        let room = Room(name: "Tent", lightFixture: .led)
        let plant = Plant(name: "One", stage: .flower)
        room.plants = [plant]

        let advice = try #require(room.lightDistanceAdvice)
        #expect(advice.isUserSet == false)
        #expect(abs(advice.range.lowerBound - 0.30) < 1e-9)
    }

    @Test func theGrowerTargetWinsOverTheCitedBand() throws {
        let room = Room(name: "Tent", lightFixture: .led)
        room.growerSetLightTargetRange = 0.25...0.45

        #expect(room.hasGrowerSetLightTarget)
        let advice = try #require(room.lightDistanceAdvice)
        #expect(advice.isUserSet)
        #expect(advice.range == 0.25...0.45)

        room.growerSetLightTargetRange = nil
        #expect(room.hasGrowerSetLightTarget == false)
        #expect(room.growerSetLightTargetRange == nil)
    }

    @Test func anInvertedStoredTargetIsIgnored() {
        let room = Room(name: "Tent", lightFixture: .led)
        room.lightTargetLowerMeters = 0.60
        room.lightTargetUpperMeters = 0.30

        #expect(room.growerSetLightTargetRange == nil)
        #expect(room.lightDistanceAdvice?.isUserSet == false)
    }

    @Test func theStoreKeepsTheTargetAndTheStageAtReading() throws {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let room = Room(name: "Tent", lightFixture: .led)
        context.insert(room)
        room.growerSetLightTargetRange = 0.25...0.45
        room.canopyDistanceMeters = 0.40
        room.canopyDistanceMeasuredAt = Date(timeIntervalSince1970: 1_799_000_000)
        room.canopyDistanceStage = .flower
        room.canopyDistanceSource = .manual
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<Room>()).first)
        #expect(stored.growerSetLightTargetRange == 0.25...0.45)
        #expect(stored.canopyDistanceStage == .flower)
        #expect(stored.canopyDistanceMeters == 0.40)
        #expect(stored.canopyDistanceSource == .manual)
        #expect(stored.lightDistanceAdvice?.isUserSet == true)
    }

    @Test func aSavedFloweringReadingNeedsNoPrompt() {
        let room = Room(name: "Tent", lightFixture: .led)
        let plant = Plant(name: "One", stage: .flower)
        room.plants = [plant]
        room.canopyDistanceMeters = 0.45
        room.canopyDistanceMeasuredAt = Date()
        room.canopyDistanceStage = .flower

        #expect(room.lightDistanceReason == nil)
    }

    @Test func theShapeChangeIsInTheSchemaAndMigration() {
        #expect(CultivationMigrationPlan.stages.count == 3)
        #expect(CultivationSchemaV4.models.count == CultivationSchemaV3.models.count)
        #expect(DataInventory.modelNames.contains("Room"))
        #expect(
            CultivationSchemaV4.models.contains { String(describing: $0) == "Room" }
        )
    }
}
