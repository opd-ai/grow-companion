//
//  SharePayload.swift
//  Grow Companion
//
//  The canonical, scoped record set that a protected share carries, and the
//  builder that projects it from local SwiftData models. Only the categories the
//  grower chose are included. The cultivation journal, photos, county and plant
//  notes are never part of a share.
//

import Foundation
import SwiftData

enum ShareCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case plantRecords
    case environment
    case careHistory
    case harvest
    case compliance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plantRecords: return String(localized: "Plant records")
        case .environment: return String(localized: "Environment")
        case .careHistory: return String(localized: "Care history")
        case .harvest: return String(localized: "Harvest and cure")
        case .compliance: return String(localized: "Compliance estimate")
        }
    }

    var subtitle: String {
        switch self {
        case .plantRecords: return String(localized: "Room and plant names, strain and stage")
        case .environment: return String(localized: "Temperature, humidity and light readings")
        case .careHistory: return String(localized: "Feeds, treatments and scouting checks")
        case .harvest: return String(localized: "Wet and dry weight, disposition and rating")
        case .compliance: return String(localized: "Counted plants and limits, labelled as an estimate")
        }
    }
}

struct ShareScope: Codable, Hashable {
    var rooms: [String]
    var plants: [String]
    var categories: [ShareCategory]
    var expiresAt: Date
}

struct SharedProfile: Codable, Hashable {
    var stateCode: String
    var stateName: String
}

struct SharedRoom: Codable, Hashable {
    var name: String
    var type: String
    var isIndoor: Bool
    var canopySquareMeters: Double?
}

struct SharedHarvest: Codable, Hashable {
    var harvestedAt: Date?
    var wetWeightGrams: Double?
    var dryWeightGrams: Double?
    var disposition: String?
    var rating: Int?
}

struct SharedPlant: Codable, Hashable {
    var name: String
    var strain: String
    var stage: String
    var room: String
    var plantedAt: Date
    var harvest: SharedHarvest?
}

struct SharedReading: Codable, Hashable {
    var date: Date
    var room: String
    var temperatureC: Double?
    var humidityPercent: Double?
    var lightPPFD: Double?
}

struct SharedFeed: Codable, Hashable {
    var date: Date
    var room: String
    var kind: String
    var volumeLiters: Double?
    var phIn: Double?
    var ecIn: Double?
    var phRunoff: Double?
    var ecRunoff: Double?
    var note: String
}

struct SharedTreatment: Codable, Hashable {
    var date: Date
    var product: String
    var dose: String
    var withdrawalDays: Int?
    var note: String
    var plant: String
    var room: String
}

struct SharedScouting: Codable, Hashable {
    var date: Date
    var findings: [String]
    var note: String
    var plant: String
    var room: String
}

struct SharedCompliance: Codable, Hashable {
    var jurisdictionCode: String
    var stateName: String
    var rulePackVersion: String
    var rulesUpdatedOn: String
    var countedPlants: Int
    var plantLimit: Int?
    var possessionGrams: Double
    var possessionLimitGrams: Double?
    var canopySquareMeters: Double
    var canopyLimitSquareMeters: Double?
    var status: String
    var notice: String
}

/// What a protected share contains, before it is encrypted.
struct GrowSharePayload: Codable, Hashable {
    static let currentFormatVersion = 1
    static let notice = "Computed by the sender's copy of Grow Companion from a bundled rule pack. It is an estimate, not legal advice; verify the current law where you live."

    var formatVersion: Int
    var shareID: UUID
    var createdAt: Date
    var expiresAt: Date
    var scope: ShareScope
    var profile: SharedProfile?
    var rooms: [SharedRoom]
    var plants: [SharedPlant]
    var readings: [SharedReading]
    var feedEvents: [SharedFeed]
    var treatments: [SharedTreatment]
    var scoutingChecks: [SharedScouting]
    var compliance: SharedCompliance?

    var totalRecords: Int {
        rooms.count + plants.count + readings.count + feedEvents.count
            + treatments.count + scoutingChecks.count + (compliance == nil ? 0 : 1)
    }

    var isExpired: Bool { expiresAt < Date() }

    func isExpired(now: Date) -> Bool { expiresAt < now }
}

enum SharePayloadBuilder {
    struct Source {
        var profile: GrowProfile?
        var rooms: [Room]
        var plants: [Plant]
        var rule: JurisdictionRule?
        var warningThreshold: Double = 0.8
    }

    static func build(
        source: Source,
        scope: ShareScope,
        now: Date = Date(),
        shareID: UUID = UUID()
    ) -> GrowSharePayload {
        let categories = Set(scope.categories)
        let rooms = source.rooms.filter { scope.rooms.contains($0.name) }
        let plants = source.plants.filter { scope.plants.contains($0.displayName) }

        let sharedRooms = categories.contains(.plantRecords) || categories.contains(.environment) || categories.contains(.careHistory)
            ? rooms.map { room in
                SharedRoom(
                    name: room.name,
                    type: room.type.title,
                    isIndoor: room.isIndoor,
                    canopySquareMeters: room.canopySquareMeters
                )
            }
            : []

        let sharedPlants = categories.contains(.plantRecords) || categories.contains(.harvest)
            ? plants.map { plant in
                SharedPlant(
                    name: plant.displayName,
                    strain: plant.displayStrain,
                    stage: plant.stage.title,
                    room: plant.room?.name ?? "",
                    plantedAt: plant.plantedAt,
                    harvest: categories.contains(.harvest) ? harvest(for: plant) : nil
                )
            }
            : []

        let readings = categories.contains(.environment)
            ? rooms
                .flatMap { $0.environmentReadings }
                .sorted { $0.date > $1.date }
                .prefix(500)
                .sorted { $0.date < $1.date }
                .map { reading in
                    SharedReading(
                        date: reading.date,
                        room: reading.room?.name ?? "",
                        temperatureC: reading.temperatureC,
                        humidityPercent: reading.humidityPercent,
                        lightPPFD: reading.lightPPFD
                    )
                }
            : []

        let feedEvents = categories.contains(.careHistory)
            ? rooms
                .flatMap { $0.feedEvents }
                .sorted { $0.date > $1.date }
                .prefix(300)
                .sorted { $0.date < $1.date }
                .map { event in
                    SharedFeed(
                        date: event.date,
                        room: event.room?.name ?? "",
                        kind: event.kind.title,
                        volumeLiters: event.volumeLiters,
                        phIn: event.phIn,
                        ecIn: event.ecIn,
                        phRunoff: event.phRunoff,
                        ecRunoff: event.ecRunoff,
                        note: event.note
                    )
                }
            : []

        let treatments = categories.contains(.careHistory)
            ? treatments(plants: plants, rooms: rooms)
            : []

        let scouting = categories.contains(.careHistory)
            ? scoutingChecks(plants: plants, rooms: rooms)
            : []

        let compliance = categories.contains(.compliance) ? compliance(source: source, rooms: rooms, plants: plants) : nil

        return GrowSharePayload(
            formatVersion: GrowSharePayload.currentFormatVersion,
            shareID: shareID,
            createdAt: now,
            expiresAt: scope.effectiveExpiry(from: now),
            scope: scope,
            profile: source.profile.map { SharedProfile(stateCode: $0.stateCode, stateName: $0.stateName) },
            rooms: sharedRooms,
            plants: sharedPlants,
            readings: readings,
            feedEvents: feedEvents,
            treatments: treatments,
            scoutingChecks: scouting,
            compliance: compliance
        )
    }

    private static func harvest(for plant: Plant) -> SharedHarvest? {
        guard plant.harvestedAt != nil || plant.dryWeightGrams != nil || plant.wetWeightGrams != nil else {
            return nil
        }
        return SharedHarvest(
            harvestedAt: plant.harvestedAt,
            wetWeightGrams: plant.wetWeightGrams,
            dryWeightGrams: plant.dryWeightGrams,
            disposition: plant.harvestDisposition?.title,
            rating: plant.rating
        )
    }

    private static func treatments(plants: [Plant], rooms: [Room]) -> [SharedTreatment] {
        var seen: Set<PersistentIdentifier> = []
        var values: [Treatment] = []

        for treatment in plants.flatMap(\.treatments) + rooms.flatMap(\.treatments) {
            guard seen.insert(treatment.persistentModelID).inserted else { continue }
            values.append(treatment)
        }

        return values
            .sorted { $0.date < $1.date }
            .map { treatment in
                SharedTreatment(
                    date: treatment.date,
                    product: treatment.productName,
                    dose: treatment.dose,
                    withdrawalDays: treatment.withdrawalDays,
                    note: treatment.note,
                    plant: treatment.plant?.displayName ?? "",
                    room: treatment.room?.name ?? ""
                )
            }
    }

    private static func scoutingChecks(plants: [Plant], rooms: [Room]) -> [SharedScouting] {
        var seen: Set<PersistentIdentifier> = []
        var values: [ScoutingCheck] = []

        for check in plants.flatMap(\.scoutingChecks) + rooms.flatMap(\.scoutingChecks) {
            guard seen.insert(check.persistentModelID).inserted else { continue }
            values.append(check)
        }

        return values
            .sorted { $0.date < $1.date }
            .suffix(200)
            .map { check in
                SharedScouting(
                    date: check.date,
                    findings: check.findings.map(\.title),
                    note: check.note,
                    plant: check.plant?.displayName ?? "",
                    room: check.room?.name ?? ""
                )
            }
    }

    private static func compliance(source: Source, rooms: [Room], plants: [Plant]) -> SharedCompliance? {
        guard let rule = source.rule else { return nil }
        let report = ComplianceEngine.report(
            plants: plants,
            rooms: rooms,
            rule: rule,
            warningThreshold: source.warningThreshold
        )

        return SharedCompliance(
            jurisdictionCode: "US-\(rule.stateCode)",
            stateName: rule.stateName,
            rulePackVersion: RulePack.version,
            rulesUpdatedOn: RulePack.displayDate(rule.verifiedOn),
            countedPlants: report.countedPlants,
            plantLimit: report.plantLimit,
            possessionGrams: report.possessionGrams,
            possessionLimitGrams: report.possessionLimitGrams,
            canopySquareMeters: report.canopySqM,
            canopyLimitSquareMeters: report.canopyLimitSqM,
            status: report.overallLevel.title,
            notice: GrowSharePayload.notice
        )
    }
}

private extension ShareScope {
    /// A share always carries an expiry, even if a caller set one in the past.
    func effectiveExpiry(from now: Date) -> Date {
        expiresAt > now ? expiresAt : Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
    }
}
