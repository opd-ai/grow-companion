//
//  BackupService.swift
//  Grow Companion
//
//  Local, password-protected backup creation and restore.
//

import Foundation
import SwiftData

struct BackupService {
    static func restore(_ root: [String: Any], context: ModelContext, appLock: AppLock) throws {
        guard let roomsValue = root["rooms"] as? [[String: Any]],
              let plantsValue = root["plants"] as? [[String: Any]] else { throw ExportServiceError.encryptionFailed }

        let lockEnabled = appLock.isEnabled
        let lockGrace = appLock.grace
        ExportService.deleteEverything(context: context, appLock: appLock)
        appLock.grace = lockGrace
        appLock.isEnabled = lockEnabled

        if let profileValue = root["profile"] as? [String: Any] {
            let profile = GrowProfile(
                ageConfirmed: profileValue["ageAttestedAt"] is String,
                ageAttestedAt: date(profileValue["ageAttestedAt"]),
                stateCode: string(profileValue["stateCode"]),
                stateName: string(profileValue["stateName"]),
                countyOrCity: string(profileValue["countyOrCity"]),
                residenceType: ResidenceType(rawValue: string(profileValue["residenceType"])) ?? .singleFamily,
                landlordConsent: profileValue["landlordConsent"] as? Bool ?? false,
                experienceLevel: ExperienceLevel(rawValue: string(profileValue["experienceLevel"])) ?? .beginner,
                onboardingCompletedAt: date(profileValue["onboardingCompletedAt"]),
                jurisdictionConfirmedAt: date(profileValue["jurisdictionConfirmedAt"]),
                educationOnly: profileValue["educationOnly"] as? Bool ?? false,
                createdAt: date(profileValue["createdAt"]) ?? Date()
            )
            context.insert(profile)
        }

        var roomByName: [String: Room] = [:]
        for value in roomsValue {
            let room = Room(
                name: string(value["name"]),
                type: RoomType(rawValue: string(value["type"])) ?? .tent,
                isIndoor: value["isIndoor"] as? Bool ?? true,
                lightType: string(value["lightType"]),
                lightWatts: value["lightWatts"] as? Int ?? 0,
                canopySquareMeters: number(value["canopySquareMeters"]),
                lightsOnMinutes: value["lightsOnMinutes"] as? Int ?? 360,
                lightsOffMinutes: value["lightsOffMinutes"] as? Int ?? 0,
                createdAt: date(value["createdAt"]) ?? Date()
            )
            context.insert(room)
            roomByName[room.name] = room
        }

        var strainByName: [String: Strain] = [:]
        if let values = root["strains"] as? [[String: Any]] {
            for value in values {
                let strain = Strain(
                    name: string(value["name"]),
                    breeder: string(value["breeder"]),
                    type: StrainType(rawValue: string(value["type"])) ?? .hybrid,
                    expectedFloweringWeeks: value["expectedFloweringWeeks"] as? Int ?? 9,
                    notes: string(value["notes"])
                )
                context.insert(strain)
                strainByName[strain.name] = strain
            }
        }

        var plantByName: [String: Plant] = [:]
        for value in plantsValue {
            let plant = Plant(
                name: string(value["name"]),
                strainName: string(value["strain"]),
                origin: PlantOrigin(rawValue: string(value["origin"])) ?? .seed,
                stage: PlantStage(rawValue: string(value["stage"])),
                container: string(value["container"]),
                plantedAt: date(value["plantedAt"]) ?? Date(),
                notes: string(value["notes"]),
                isMother: value["isMother"] as? Bool ?? false,
                room: roomByName[string(value["room"])],
                strain: strainByName[string(value["strain"])]
            )
            plant.harvestedAt = date(value["harvestedAt"])
            plant.wetWeightGrams = number(value["wetWeightGrams"])
            plant.dryWeightGrams = number(value["dryWeightGrams"])
            plant.harvestDispositionRaw = string(value["harvestDisposition"])
            plant.ratingRaw = value["rating"] as? Int
            plant.tastingNotes = string(value["tastingNotes"])
            context.insert(plant)
            plantByName[plant.name] = plant

            if let history = value["stageHistory"] as? [[String: Any]] {
                for eventValue in history {
                    let event = StageEvent(
                        stage: PlantStage(rawValue: string(eventValue["stage"])) ?? plant.stage,
                        date: date(eventValue["date"]) ?? plant.plantedAt,
                        note: string(eventValue["note"]),
                        isBackfilled: eventValue["backfilled"] as? Bool ?? false,
                        plant: plant
                    )
                    context.insert(event)
                }
            }
        }

        if let values = root["treatments"] as? [[String: Any]] {
            for value in values {
                let treatment = Treatment(
                    productName: string(value["productName"]),
                    dose: string(value["dose"]),
                    date: date(value["date"]) ?? Date(),
                    withdrawalDays: value["withdrawalDays"] as? Int,
                    note: string(value["note"]),
                    plant: plantByName[string(value["plant"])],
                    room: roomByName[string(value["room"])]
                )
                context.insert(treatment)
            }
        }

        if let values = root["equipment"] as? [[String: Any]] {
            for value in values {
                let item = Equipment(
                    name: string(value["name"]),
                    serviceIntervalDays: value["serviceIntervalDays"] as? Int ?? 90,
                    lastServicedAt: date(value["lastServicedAt"]) ?? Date(),
                    room: roomByName[string(value["room"])]
                )
                context.insert(item)
            }
        }

        if let values = root["scoutingChecks"] as? [[String: Any]] {
            for value in values {
                let check = ScoutingCheck(
                    date: date(value["date"]) ?? Date(),
                    findings: (value["findings"] as? [String] ?? []).compactMap(ObservationTag.init(rawValue:)),
                    note: string(value["note"]),
                    plant: plantByName[string(value["plant"])],
                    room: roomByName[string(value["room"])]
                )
                context.insert(check)
            }
        }

        if let values = root["environmentAlerts"] as? [[String: Any]] {
            for value in values {
                let target = (number(value["targetLow"]) ?? 0)...(number(value["targetHigh"]) ?? 0)
                let alert = EnvironmentAlert(
                    metric: EnvironmentMetric(rawValue: string(value["metric"])) ?? .temperature,
                    value: number(value["value"]) ?? 0,
                    target: target,
                    detectedAt: date(value["detectedAt"]) ?? Date(),
                    room: roomByName[string(value["room"])]
                )
                alert.acknowledgedAt = date(value["acknowledgedAt"])
                context.insert(alert)
            }
        }

        if let values = root["journal"] as? [[String: Any]] {
            for value in values {
                let entry = JournalEntry(
                    kind: JournalKind(rawValue: string(value["kind"])) ?? .note,
                    text: string(value["text"]),
                    tag: ObservationTag(rawValue: string(value["tag"])),
                    photoFileName: string(value["photo"]),
                    createdAt: date(value["createdAt"]) ?? Date(),
                    plant: plantByName[string(value["plant"])],
                    room: roomByName[string(value["room"])]
                )
                context.insert(entry)
            }
        }

        if let photos = root["photos"] as? [[String: Any]] {
            for photo in photos {
                let name = string(photo["fileName"])
                guard let data = Data(base64Encoded: string(photo["data"])), !name.isEmpty else { continue }
                try? data.write(to: PhotoStore.url(for: name), options: [.atomic, .completeFileProtection])
            }
        }

        try context.save()
    }

    private static func string(_ value: Any?) -> String { value as? String ?? "" }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}
