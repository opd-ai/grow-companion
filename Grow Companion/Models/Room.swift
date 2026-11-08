//
//  Room.swift
//  Grow Companion
//
//  A physical space with its own canopy, light and photoperiod schedule.
//

import Foundation
import SwiftData

@Model
final class Room {
    var name: String = "Grow Room"
    var typeRaw: String = RoomType.tent.rawValue
    var isIndoor: Bool = true
    var lightType: String = ""
    var lightWatts: Int = 0
    var lightFixtureRaw: String = LightFixtureType.led.rawValue
    var canopySquareMeters: Double?
    var canopyDistanceMeters: Double?
    var canopyDistanceMeasuredAt: Date?
    var canopyDistanceSourceRaw: String?
    /// The stage the room was in when the distance was confirmed, so a later
    /// stage change can prompt a re-measure.
    var canopyDistanceStageRaw: String?

    /// A grower-set target replaces the app's cited band for this fixture.
    var lightTargetLowerMeters: Double?
    var lightTargetUpperMeters: Double?

    /// Reservoir or feed-plan targets for this room.
    var feedTargetPH: Double?
    var feedTargetEC: Double?

    /// The feed schedule applied to this room, and the day its week 1 began.
    var feedSchedule: FeedSchedule?
    var feedScheduleStartDate: Date?

    /// Minutes from midnight when the lights come on.
    var lightsOnMinutes: Int = 360
    /// Minutes from midnight when the lights go off.
    var lightsOffMinutes: Int = 0

    /// Minutes an environment metric must remain out of range before alerting.
    var sustainedAlertMinutes: Int = 10

    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Plant.room)
    var plants: [Plant] = []

    @Relationship(deleteRule: .nullify, inverse: \JournalEntry.room)
    var journalEntries: [JournalEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \LightScheduleEvent.room)
    var lightScheduleEvents: [LightScheduleEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \EnvironmentReading.room)
    var environmentReadings: [EnvironmentReading] = []

    @Relationship(deleteRule: .nullify, inverse: \SensorDevice.room)
    var sensors: [SensorDevice] = []

    @Relationship(deleteRule: .cascade, inverse: \FeedEvent.room)
    var feedEvents: [FeedEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \CalibrationEvent.room)
    var calibrationEvents: [CalibrationEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \CareReminder.room)
    var careReminders: [CareReminder] = []

    @Relationship(deleteRule: .cascade, inverse: \Treatment.room)
    var treatments: [Treatment] = []

    @Relationship(deleteRule: .cascade, inverse: \Equipment.room)
    var equipment: [Equipment] = []

    @Relationship(deleteRule: .cascade, inverse: \ScoutingCheck.room)
    var scoutingChecks: [ScoutingCheck] = []

    @Relationship(deleteRule: .cascade, inverse: \EnvironmentAlert.room)
    var environmentAlerts: [EnvironmentAlert] = []

    init(
        name: String = "Grow Room",
        type: RoomType = .tent,
        isIndoor: Bool = true,
        lightType: String = "",
        lightWatts: Int = 0,
        lightFixture: LightFixtureType = .led,
        canopySquareMeters: Double? = nil,
        canopyDistanceMeters: Double? = nil,
        canopyDistanceMeasuredAt: Date? = nil,
        canopyDistanceSource: LightDistanceSource? = nil,
        canopyDistanceStage: PlantStage? = nil,
        lightTargetLowerMeters: Double? = nil,
        lightTargetUpperMeters: Double? = nil,
        lightsOnMinutes: Int = 360,
        lightsOffMinutes: Int = 0,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.isIndoor = isIndoor
        self.lightType = lightType
        self.lightWatts = lightWatts
        self.lightFixtureRaw = lightFixture.rawValue
        self.canopySquareMeters = canopySquareMeters
        self.canopyDistanceMeters = canopyDistanceMeters
        self.canopyDistanceMeasuredAt = canopyDistanceMeasuredAt
        self.canopyDistanceSourceRaw = canopyDistanceSource?.rawValue
        self.canopyDistanceStageRaw = canopyDistanceStage?.rawValue
        self.lightTargetLowerMeters = lightTargetLowerMeters
        self.lightTargetUpperMeters = lightTargetUpperMeters
        self.lightsOnMinutes = lightsOnMinutes
        self.lightsOffMinutes = lightsOffMinutes
        self.createdAt = createdAt
    }

    var lightFixture: LightFixtureType {
        get { LightFixtureType(rawValue: lightFixtureRaw) ?? .led }
        set { lightFixtureRaw = newValue.rawValue }
    }

    var canopyDistanceSource: LightDistanceSource? {
        get { canopyDistanceSourceRaw.flatMap(LightDistanceSource.init(rawValue:)) }
        set { canopyDistanceSourceRaw = newValue?.rawValue }
    }

    var canopyDistanceStage: PlantStage? {
        get { canopyDistanceStageRaw.flatMap(PlantStage.init(rawValue:)) }
        set { canopyDistanceStageRaw = newValue?.rawValue }
    }

    /// The grower's own target band, or nil when the app's cited band applies.
    var growerSetLightTargetRange: ClosedRange<Double>? {
        get {
            guard let lower = lightTargetLowerMeters,
                  let upper = lightTargetUpperMeters,
                  lower > 0, lower < upper else { return nil }
            return lower...upper
        }
        set {
            lightTargetLowerMeters = newValue?.lowerBound
            lightTargetUpperMeters = newValue?.upperBound
        }
    }

    var hasGrowerSetLightTarget: Bool { growerSetLightTargetRange != nil }

    var type: RoomType {
        get { RoomType(rawValue: typeRaw) ?? .tent }
        set { typeRaw = newValue.rawValue }
    }

    /// Plants that still occupy space in the room (everything before storage).
    var activePlants: [Plant] {
        plants.filter { $0.stage != .storage }
    }

    var hasFloweringPlants: Bool {
        plants.contains { $0.stage == .flower }
    }

    var floweringPlantCount: Int {
        plants.filter { $0.stage == .flower }.count
    }

    var lightHoursPerDay: Double {
        LightSchedule.hours(on: lightsOnMinutes, off: lightsOffMinutes)
    }

    var lightScheduleSummary: String {
        LightSchedule.summary(on: lightsOnMinutes, off: lightsOffMinutes)
    }

    /// Most recent schedule change first.
    var sortedLightEvents: [LightScheduleEvent] {
        lightScheduleEvents.sorted { $0.date > $1.date }
    }

    var placementLabel: String {
        isIndoor ? "Indoor" : "Outdoor"
    }
}
