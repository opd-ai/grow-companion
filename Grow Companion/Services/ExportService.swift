//
//  ExportService.swift
//  Grow Companion
//
//  One archive with everything the grower chose: JSON, CSV files and journal
//  photos, optionally encrypted with a password. Also holds the delete-all
//  routine used by the data controls screen.
//

import CryptoKit
import Foundation
import Security
import SwiftData

struct ExportOptions {
    var includeJournal: Bool = false
    var includePhotos: Bool = false
    var password: String?
}

struct ExportPayload {
    let data: Data
    let fileName: String
    let isEncrypted: Bool
}

/// Everything the data controls can export, collected before the archive is
/// built. `counts` is the whole-store model manifest, so an export states what
/// it holds even for record types that have no rows yet.
struct ExportSnapshot {
    var profile: GrowProfile?
    var rooms: [Room] = []
    var plants: [Plant] = []
    var strains: [Strain] = []
    var reminders: [CareReminder] = []
    var dryingSessions: [DryingSession] = []
    var journal: [JournalEntry] = []
    var feedSchedules: [FeedSchedule] = []
    var cycleArchives: [CycleArchive] = []
    var sensors: [SensorDevice] = []
    var shareGrants: [ShareGrant] = []
    var complianceSnapshots: [ComplianceSnapshot] = []
    var ruleEvaluationEvents: [RuleEvaluationEvent] = []
    var goals: [GrowGoal] = []
    var counts: [String: Int] = [:]
}

/// What a restore did, so the UI reports it instead of guessing.
struct RestoreReport {
    let backupVersion: Int
    let inserted: [String: Int]

    var totalInserted: Int { inserted.values.reduce(0, +) }
}

enum ExportServiceError: LocalizedError {
    case encryptionFailed
    case unsupportedBackupVersion
    case invalidBackup(String)
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "The password-protected archive could not be created."
        case .unsupportedBackupVersion:
            return "This backup was created by a newer version of Grow Companion and cannot be opened here."
        case .invalidBackup(let detail):
            return "The backup is not complete: \(detail)"
        case .deletionFailed(let detail):
            return "The records could not be deleted: \(detail)"
        }
    }
}

enum ExportService {
    // MARK: - Build

    /// The model types written into the JSON archive, by type name. The coverage
    /// test compares this with `DataInventory.modelNames`, so adding a model
    /// without exporting it fails the test suite.
    static let exportedModelNames: [String] = [
        "GrowProfile", "Room", "Plant", "CycleArchive", "Strain",
        "StageEvent", "JournalEntry", "LightScheduleEvent",
        "EnvironmentReading", "SensorDevice", "ShareGrant", "ShareAccessLog",
        "EnvironmentAlert", "FeedEvent", "CalibrationEvent", "CareReminder",
        "DryingSession", "DryingCheck", "CureBurp", "TrainingSession",
        "Treatment", "Equipment", "ServiceRecord", "ScoutingCheck",
        "FeedSchedule", "FeedWeek", "FeedProduct",
        "ComplianceSnapshot", "RuleEvaluationEvent", "GrowGoal"
    ]

    static func build(snapshot: ExportSnapshot, options: ExportOptions) throws -> ExportPayload {
        var archive = SimpleZipArchive()

        let json = try jsonData(snapshot: snapshot, options: options)
        archive.add(json, as: "grow-companion.json")

        for file in csvFiles(snapshot: snapshot, options: options) {
            archive.add(file.data, as: "csv/\(file.name)")
        }

        if options.includeJournal && options.includePhotos {
            for entry in snapshot.journal {
                guard let fileName = entry.photoFileName else { continue }
                guard let data = try? Data(contentsOf: PhotoStore.url(for: fileName)) else { continue }
                archive.add(data, as: "photos/\(fileName)")
            }
        }

        archive.add(Data(readme.utf8), as: "README.txt")

        let zip = archive.makeData()
        let stamp = fileStamp()

        if let password = options.password, !password.isEmpty {
            let encrypted = try seal(zip, password: password, header: exportHeaderV2)
            return ExportPayload(
                data: encrypted,
                fileName: "Grow-Companion-Export-\(stamp)-protected",
                isEncrypted: true
            )
        }

        return ExportPayload(
            data: zip,
            fileName: "Grow-Companion-Export-\(stamp)",
            isEncrypted: false
        )
    }

    // MARK: - JSON

    static func jsonData(snapshot: ExportSnapshot, options: ExportOptions) throws -> Data {
        let rooms = snapshot.rooms
        let plants = snapshot.plants

        let readings = rooms.flatMap { $0.environmentReadings }.sorted { $0.date < $1.date }
        let feeds = rooms.flatMap { $0.feedEvents }.sorted { $0.date < $1.date }
        let calibrations = rooms.flatMap { $0.calibrationEvents }.sorted { $0.date < $1.date }
        let lightEvents = rooms.flatMap { $0.lightScheduleEvents }.sorted { $0.date < $1.date }
        let treatments = plants.flatMap(\.treatments) + rooms.flatMap(\.treatments)
        let equipment = rooms.flatMap(\.equipment)
        let serviceRecords = equipment.flatMap(\.serviceRecords)
        let scoutingChecks = plants.flatMap(\.scoutingChecks) + rooms.flatMap(\.scoutingChecks)
        let environmentAlerts = rooms.flatMap(\.environmentAlerts)
        let trainingSessions = plants.flatMap(\.trainingSessions).sorted { $0.date < $1.date }

        let counts = snapshot.counts
        let profileValue: Any = snapshot.profile.map { profileDictionary($0) as Any } ?? NSNull()

        let root: [String: Any] = [
            "app": "Grow Companion",
            "formatVersion": currentFormatVersion,
            "exportedAt": iso(Date()),
            "producer": producerDictionary,
            "unitSystem": UserDefaults.standard.string(forKey: SettingsKey.unitSystem) ?? "metric",
            "options": [
                "journal": options.includeJournal,
                "photos": options.includePhotos
            ],
            "manifest": [
                "formatVersion": currentFormatVersion,
                "generatedAt": iso(Date()),
                "models": DataInventory.modelNames,
                "counts": counts,
                "total": DataInventory.total(of: counts),
                "journalIncluded": options.includeJournal,
                "photosIncluded": options.includeJournal && options.includePhotos
            ],
            "profile": profileValue,
            "rooms": rooms.map(roomDictionary),
            "plants": plants.map(plantDictionary),
            "strains": snapshot.strains.map(strainDictionary),
            "careReminders": snapshot.reminders.map(reminderDictionary),
            "environmentReadings": readings.map(readingDictionary),
            "feedEvents": feeds.map(feedDictionary),
            "calibrations": calibrations.map(calibrationDictionary),
            "lightScheduleEvents": lightEvents.map(lightDictionary),
            "dryingSessions": snapshot.dryingSessions.map(dryingDictionary),
            "treatments": treatments.map(treatmentDictionary),
            "equipment": equipment.map(equipmentDictionary),
            "serviceRecords": serviceRecords.map(serviceRecordDictionary),
            "scoutingChecks": scoutingChecks.map(scoutingDictionary),
            "environmentAlerts": environmentAlerts.map(environmentAlertDictionary),
            "trainingSessions": trainingSessions.map(trainingDictionary),
            "feedSchedules": snapshot.feedSchedules.map(feedScheduleDictionary),
            "cycleArchives": snapshot.cycleArchives.map(cycleArchiveDictionary),
            "sensors": snapshot.sensors.map(sensorDictionary),
            "shareGrants": snapshot.shareGrants.map(shareGrantDictionary),
            "complianceSnapshots": snapshot.complianceSnapshots
                .sorted { $0.capturedAt < $1.capturedAt }
                .map(complianceSnapshotDictionary),
            "ruleEvaluationEvents": snapshot.ruleEvaluationEvents
                .sorted { $0.evaluatedAt < $1.evaluatedAt }
                .map(ruleEvaluationEventDictionary),
            "goals": snapshot.goals
                .sorted { $0.createdAt < $1.createdAt }
                .map(goalDictionary),
            "journal": options.includeJournal ? snapshot.journal.map(journalDictionary) : []
        ]

        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private static var producerDictionary: [String: Any] {
        let info = Bundle.main.infoDictionary
        return [
            "app": "Grow Companion",
            "version": info?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": info?["CFBundleVersion"] as? String ?? "unknown",
            // The explicit versioned SwiftData schema this build writes.
            "recordSchema": "cultivation-v3",
            "recordSchemaVersion": 3
        ]
    }

    private static func goalDictionary(_ goal: GrowGoal) -> [String: Any] {
        [
            "dryYieldTargetGrams": boxed(goal.dryYieldTargetGrams),
            "floweringWeeksTarget": boxed(goal.floweringWeeksTarget),
            "loggingCompletenessTargetPercent": boxed(goal.loggingCompletenessTargetPercent),
            "createdAt": iso(goal.createdAt),
            "updatedAt": iso(goal.updatedAt)
        ]
    }

    private static func profileDictionary(_ profile: GrowProfile) -> [String: Any] {
        [
            "stateCode": profile.stateCode,
            "stateName": profile.stateName,
            "countyOrCity": profile.countyOrCity,
            "residenceType": profile.residenceTypeRaw,
            "landlordConsent": profile.landlordConsent,
            "experienceLevel": profile.experienceLevelRaw,
            "ageAttestedAt": iso(profile.ageAttestedAt),
            "onboardingCompletedAt": iso(profile.onboardingCompletedAt),
            "jurisdictionConfirmedAt": iso(profile.jurisdictionConfirmedAt),
            "educationOnly": profile.educationOnly,
            "createdAt": iso(profile.createdAt)
        ]
    }

    private static func roomDictionary(_ room: Room) -> [String: Any] {
        [
            "name": room.name,
            "type": room.typeRaw,
            "isIndoor": room.isIndoor,
            "lightType": room.lightType,
            "lightWatts": room.lightWatts,
            "lightFixture": room.lightFixtureRaw,
            "canopySquareMeters": boxed(room.canopySquareMeters),
            "canopyDistanceMeters": boxed(room.canopyDistanceMeters),
            "canopyDistanceMeasuredAt": iso(room.canopyDistanceMeasuredAt),
            "canopyDistanceSource": room.canopyDistanceSourceRaw ?? "",
            "feedTargetPH": boxed(room.feedTargetPH),
            "feedTargetEC": boxed(room.feedTargetEC),
            "feedSchedule": room.feedSchedule?.name ?? "",
            "feedScheduleStartDate": iso(room.feedScheduleStartDate),
            "lightsOnMinutes": room.lightsOnMinutes,
            "lightsOffMinutes": room.lightsOffMinutes,
            "sustainedAlertMinutes": room.sustainedAlertMinutes,
            "createdAt": iso(room.createdAt)
        ]
    }

    private static func plantDictionary(_ plant: Plant) -> [String: Any] {
        let history: [[String: Any]] = plant.sortedStageEvents.map { event in
            [
                "stage": event.stageRaw,
                "date": iso(event.date),
                "note": event.note,
                "backfilled": event.isBackfilled
            ]
        }

        return [
            "name": plant.name,
            "strain": plant.displayStrain,
            "breeder": plant.strain?.breeder ?? "",
            "origin": plant.originRaw,
            "stage": plant.stageRaw,
            "room": plant.room?.name ?? "",
            "container": plant.container,
            "plantedAt": iso(plant.plantedAt),
            "harvestedAt": iso(plant.harvestedAt),
            "wetWeightGrams": boxed(plant.wetWeightGrams),
            "dryWeightGrams": boxed(plant.dryWeightGrams),
            "harvestDisposition": plant.harvestDispositionRaw ?? "",
            "rating": boxed(plant.ratingRaw),
            "tastingNotes": plant.tastingNotes,
            "notes": plant.notes,
            "isMother": plant.isMother,
            "mother": plant.mother?.name ?? "",
            "ratedAt": iso(plant.ratedAt),
            "cycleArchive": plant.cycleArchive?.name ?? "",
            "stageHistory": history
        ]
    }

    private static func strainDictionary(_ strain: Strain) -> [String: Any] {
        let observed = StrainInsights.observedAverage(for: strain)
        return [
            "name": strain.name,
            "breeder": strain.breeder,
            "type": strain.typeRaw,
            "expectedFloweringWeeks": strain.expectedFloweringWeeks,
            "claimedYield": strain.claimedYield,
            "parentLines": strain.parentLines,
            "lineageStatus": strain.lineageStatusRaw,
            "breederSource": strain.breederSource,
            "notes": strain.notes,
            "createdAt": iso(strain.createdAt),
            "plantCount": strain.plants.count,
            "observedFloweringDays": boxed(observed?.days),
            "finishedCycles": observed?.count ?? 0,
            "averageRating": boxed(strain.averageRating)
        ]
    }

    private static func reminderDictionary(_ reminder: CareReminder) -> [String: Any] {
        [
            "title": reminder.title,
            "kind": reminder.kindRaw,
            "timeOfDayMinutes": reminder.timeOfDayMinutes,
            "repeatDays": reminder.repeatDays,
            "isEnabled": reminder.isEnabled,
            "lastCompletedAt": iso(reminder.lastCompletedAt),
            "nextDueDate": iso(reminder.nextDueDate),
            "room": reminder.room?.name ?? ""
        ]
    }

    private static func readingDictionary(_ reading: EnvironmentReading) -> [String: Any] {
        [
            "date": iso(reading.date),
            "temperatureC": boxed(reading.temperatureC),
            "humidityPercent": boxed(reading.humidityPercent),
            "lightPPFD": boxed(reading.lightPPFD),
            "isHourlyAverage": reading.isHourlyAverage,
            "sampleCount": reading.sampleCount,
            "source": reading.sourceRaw,
            "sensor": reading.sensor?.name ?? "",
            "room": reading.room?.name ?? ""
        ]
    }

    private static func feedDictionary(_ event: FeedEvent) -> [String: Any] {
        [
            "date": iso(event.date),
            "kind": event.kindRaw,
            "volumeLiters": boxed(event.volumeLiters),
            "phIn": boxed(event.phIn),
            "ecIn": boxed(event.ecIn),
            "phRunoff": boxed(event.phRunoff),
            "ecRunoff": boxed(event.ecRunoff),
            "note": event.note,
            "room": event.room?.name ?? ""
        ]
    }

    private static func calibrationDictionary(_ event: CalibrationEvent) -> [String: Any] {
        [
            "date": iso(event.date),
            "meter": event.meterRaw,
            "reading": boxed(event.reading),
            "note": event.note,
            "nextDueDate": iso(event.nextDueDate),
            "room": event.room?.name ?? ""
        ]
    }

    private static func lightDictionary(_ event: LightScheduleEvent) -> [String: Any] {
        [
            "date": iso(event.date),
            "previousOnMinutes": event.previousOnMinutes,
            "previousOffMinutes": event.previousOffMinutes,
            "newOnMinutes": event.newOnMinutes,
            "newOffMinutes": event.newOffMinutes,
            "note": event.note,
            "hadFloweringPlants": event.hadFloweringPlants,
            "room": event.room?.name ?? ""
        ]
    }

    private static func dryingDictionary(_ session: DryingSession) -> [String: Any] {
        let checks: [[String: Any]] = session.sortedChecks.map { check in
            [
                "date": iso(check.date),
                "humidityPercent": boxed(check.humidityPercent),
                "temperatureC": boxed(check.temperatureC),
                "stemSnap": check.stemSnapRaw ?? "",
                "note": check.note
            ]
        }
        let burps: [[String: Any]] = session.sortedBurps.map { burp in
            [
                "date": iso(burp.date),
                "note": burp.note
            ]
        }

        return [
            "plant": session.plant?.name ?? "",
            "startedAt": iso(session.startedAt),
            "phase": session.phaseRaw,
            "profile": session.profileRaw,
            "targetTemperatureLow": session.targetTemperatureLow,
            "targetTemperatureHigh": session.targetTemperatureHigh,
            "targetHumidityLow": session.targetHumidityLow,
            "targetHumidityHigh": session.targetHumidityHigh,
            "curingStartedAt": iso(session.curingStartedAt),
            "curingHumidityLow": session.curingHumidityLow,
            "curingHumidityHigh": session.curingHumidityHigh,
            "burpMode": session.burpModeRaw,
            "lastBurpedAt": iso(session.lastBurpedAt),
            "endedAt": iso(session.endedAt),
            "checks": checks,
            "burps": burps
        ]
    }

    private static func journalDictionary(_ entry: JournalEntry) -> [String: Any] {
        [
            "createdAt": iso(entry.createdAt),
            "kind": entry.kindRaw,
            "text": entry.text,
            "tag": entry.tagRaw ?? "",
            "plant": entry.plant?.name ?? "",
            "room": entry.room?.name ?? "",
            "photo": entry.photoFileName ?? ""
        ]
    }

    private static func treatmentDictionary(_ treatment: Treatment) -> [String: Any] {
        [
            "date": iso(treatment.date),
            "productName": treatment.productName,
            "dose": treatment.dose,
            "withdrawalDays": boxed(treatment.withdrawalDays),
            "note": treatment.note,
            "plant": treatment.plant?.name ?? "",
            "room": treatment.room?.name ?? ""
        ]
    }

    private static func equipmentDictionary(_ item: Equipment) -> [String: Any] {
        [
            "name": item.name,
            "room": item.room?.name ?? "",
            "serviceIntervalDays": item.serviceIntervalDays,
            "lastServicedAt": iso(item.lastServicedAt),
            "nextServiceDate": iso(item.nextServiceDate)
        ]
    }

    private static func serviceRecordDictionary(_ record: ServiceRecord) -> [String: Any] {
        [
            "date": iso(record.date),
            "note": record.note,
            "equipment": record.equipment?.name ?? ""
        ]
    }

    private static func scoutingDictionary(_ check: ScoutingCheck) -> [String: Any] {
        [
            "date": iso(check.date),
            "findings": check.findingRaws,
            "note": check.note,
            "photo": check.photoFileName ?? "",
            "plant": check.plant?.name ?? "",
            "room": check.room?.name ?? ""
        ]
    }

    private static func environmentAlertDictionary(_ alert: EnvironmentAlert) -> [String: Any] {
        [
            "metric": alert.metricRaw,
            "value": alert.value,
            "targetLow": alert.targetLow,
            "targetHigh": alert.targetHigh,
            "detectedAt": iso(alert.detectedAt),
            "acknowledgedAt": iso(alert.acknowledgedAt),
            "room": alert.room?.name ?? ""
        ]
    }

    private static func trainingDictionary(_ session: TrainingSession) -> [String: Any] {
        [
            "date": iso(session.date),
            "method": session.methodRaw,
            "nodesAffected": boxed(session.nodesAffected),
            "note": session.note,
            "plant": session.plant?.name ?? ""
        ]
    }

    private static func feedScheduleDictionary(_ schedule: FeedSchedule) -> [String: Any] {
        let weeks: [[String: Any]] = schedule.sortedWeeks.map { week in
            [
                "weekNumber": week.weekNumber,
                "targetPH": boxed(week.targetPH),
                "targetEC": boxed(week.targetEC),
                "products": week.sortedProducts.map { product in
                    [
                        "name": product.name,
                        "doseMLPerLiter": boxed(product.doseMLPerLiter),
                        "sortIndex": product.sortIndex
                    ]
                }
            ]
        }

        return [
            "name": schedule.name,
            "weekCount": schedule.weekCount,
            "createdAt": iso(schedule.createdAt),
            "appliedRooms": schedule.sortedAppliedRooms.map(\.name),
            "weeks": weeks
        ]
    }

    private static func cycleArchiveDictionary(_ archive: CycleArchive) -> [String: Any] {
        [
            "name": archive.name,
            "completedAt": iso(archive.completedAt),
            "plants": archive.sortedPlants.map(\.name),
            "dryYieldGrams": boxed(archive.dryYieldGrams)
        ]
    }

    private static func sensorDictionary(_ sensor: SensorDevice) -> [String: Any] {
        [
            "name": sensor.name,
            "identifier": sensor.identifier,
            "transport": sensor.transportRaw,
            "pairedAt": iso(sensor.pairedAt),
            "lastSeenAt": iso(sensor.lastSeenAt),
            "lastReadingAt": iso(sensor.lastReadingAt),
            "isConnected": sensor.isConnected,
            "room": sensor.room?.name ?? ""
        ]
    }

    private static func shareGrantDictionary(_ grant: ShareGrant) -> [String: Any] {
        [
            "recipientName": grant.recipientName,
            "rooms": grant.roomNames,
            "plants": grant.plantNames,
            "categories": grant.categories,
            "createdAt": iso(grant.createdAt),
            "expiresAt": iso(grant.expiresAt),
            "revokedAt": iso(grant.revokedAt),
            "accessLogs": grant.accessLogs.sorted { $0.date < $1.date }.map { log in
                ["date": iso(log.date), "action": log.action]
            }
        ]
    }

    private static func complianceSnapshotDictionary(_ snapshot: ComplianceSnapshot) -> [String: Any] {
        [
            "id": snapshot.snapshotID.uuidString,
            "capturedAt": iso(snapshot.capturedAt),
            "jurisdictionCode": snapshot.jurisdictionCode,
            "stateName": snapshot.stateName,
            "rulePackVersion": snapshot.rulePackVersion,
            "ruleVerifiedOn": snapshot.ruleVerifiedOn,
            "citation": snapshot.citation,
            "sourceURL": snapshot.sourceURL,
            "countedPlants": snapshot.countedPlantTotal,
            "stageCounts": Dictionary(
                uniqueKeysWithValues: snapshot.stageCounts.map { ($0.key.rawValue, $0.value) }
            ),
            "retainedDryWeightGrams": snapshot.retainedDryWeightGrams,
            "canopySquareMeters": snapshot.canopySquareMeters,
            "plantLimit": boxed(snapshot.plantLimit),
            "possessionLimitGrams": boxed(snapshot.possessionLimitGrams),
            "canopyLimitSqM": boxed(snapshot.canopyLimitSqM),
            "warningThreshold": snapshot.warningThreshold,
            "cultivable": snapshot.cultivable,
            "countedStages": snapshot.countedStages.map(\.rawValue),
            "countsClones": snapshot.countsClones,
            "limitScope": snapshot.limitScopeRaw,
            "plantLevel": snapshot.plantLevelRaw,
            "possessionLevel": snapshot.possessionLevelRaw,
            "canopyLevel": snapshot.canopyLevelRaw,
            "overallLevel": snapshot.overallLevelRaw,
            "fingerprint": snapshot.fingerprint,
            "isUpgradeBaseline": snapshot.isUpgradeBaseline,
            "schemaVersion": snapshot.schemaVersion
        ]
    }

    private static func ruleEvaluationEventDictionary(_ event: RuleEvaluationEvent) -> [String: Any] {
        [
            "id": event.eventID.uuidString,
            "priorSnapshotID": event.priorSnapshotID.uuidString,
            "priorPackVersion": event.priorPackVersion,
            "newPackVersion": event.newPackVersion,
            "priorRuleVerifiedOn": event.priorRuleVerifiedOn,
            "newRuleVerifiedOn": event.newRuleVerifiedOn,
            "jurisdictionCode": event.jurisdictionCode,
            "evaluatedAt": iso(event.evaluatedAt),
            "outcome": event.outcomeRaw,
            "changedSummary": event.changedSummary,
            "changedFields": event.changedFields.map { change in
                [
                    "field": change.field,
                    "kind": change.kind.rawValue,
                    "previousNumber": boxed(change.previousNumber),
                    "newNumber": boxed(change.newNumber),
                    "previousText": change.previousText,
                    "newText": change.newText
                ]
            },
            "metrics": event.metrics.map { metric in
                [
                    "metric": metric.metric,
                    "previousValue": metric.previousValue,
                    "previousLimit": boxed(metric.previousLimit),
                    "previousLevel": metric.previousLevel,
                    "currentValue": metric.currentValue,
                    "currentLimit": boxed(metric.currentLimit),
                    "currentLevel": metric.currentLevel,
                    "comparable": metric.comparable
                ]
            },
            "citation": event.citation,
            "sourceURL": event.sourceURL,
            "acknowledgedAt": iso(event.acknowledgedAt),
            "schemaVersion": event.schemaVersion
        ]
    }

    // MARK: - CSV

    private struct CsvFile {
        let name: String
        let data: Data
    }

    private static func csvFiles(snapshot: ExportSnapshot, options: ExportOptions) -> [CsvFile] {
        var files: [CsvFile] = []
        let rooms = snapshot.rooms
        let plants = snapshot.plants
        let strains = snapshot.strains
        let reminders = snapshot.reminders
        let dryingSessions = snapshot.dryingSessions
        let journal = snapshot.journal

        files.append(
            CsvFile(
                name: "plants.csv",
                data: csvData(
                    headers: [
                        "Name", "Strain", "Breeder", "Origin", "Stage", "Room", "Container",
                        "Planted", "Harvested", "Wet grams", "Dry grams", "Disposition",
                        "Rating", "Tasting notes", "Notes"
                    ],
                    rows: plants.map { plant in
                        [
                            plant.name,
                            plant.displayStrain,
                            plant.strain?.breeder ?? "",
                            plant.origin.title,
                            plant.stage.title,
                            plant.room?.name ?? "",
                            plant.container,
                            timestamp(plant.plantedAt),
                            plant.harvestedAt.map(timestamp) ?? "",
                            numberText(plant.wetWeightGrams),
                            numberText(plant.dryWeightGrams),
                            plant.harvestDisposition?.title ?? "",
                            plant.rating.map { String($0) } ?? "",
                            plant.tastingNotes,
                            plant.notes
                        ]
                    }
                )
            )
        )

        files.append(
            CsvFile(
                name: "rooms.csv",
                data: csvData(
                    headers: [
                        "Name", "Type", "Indoor", "Canopy square metres", "Light type",
                        "Watts", "Lights on", "Lights off"
                    ],
                    rows: rooms.map { room in
                        [
                            room.name,
                            room.type.title,
                            room.isIndoor ? "Yes" : "No",
                            numberText(room.canopySquareMeters),
                            room.lightType,
                            room.lightWatts > 0 ? String(room.lightWatts) : "",
                            LightSchedule.timeLabel(room.lightsOnMinutes),
                            LightSchedule.timeLabel(room.lightsOffMinutes)
                        ]
                    }
                )
            )
        )

        files.append(
            CsvFile(
                name: "strains.csv",
                data: csvData(
                    headers: [
                        "Name", "Breeder", "Type", "Expected flowering weeks",
                        "Observed flowering days", "Finished cycles", "Average rating", "Notes"
                    ],
                    rows: strains.map { strain in
                        let observed = StrainInsights.observedAverage(for: strain)
                        return [
                            strain.name,
                            strain.breeder,
                            strain.type.title,
                            String(strain.expectedFloweringWeeks),
                            numberText(observed?.days, digits: 1),
                            String(observed?.count ?? 0),
                            numberText(strain.averageRating, digits: 1),
                            strain.notes
                        ]
                    }
                )
            )
        )

        let readings = rooms.flatMap { $0.environmentReadings }.sorted { $0.date < $1.date }
        files.append(
            CsvFile(
                name: "environment_readings.csv",
                data: csvData(
                    headers: ["Date", "Room", "Temperature C", "Humidity %", "Light PPFD", "Hourly average", "Samples"],
                    rows: readings.map { reading in
                        [
                            timestamp(reading.date),
                            reading.room?.name ?? "",
                            numberText(reading.temperatureC, digits: 1),
                            numberText(reading.humidityPercent, digits: 0),
                            numberText(reading.lightPPFD, digits: 0),
                            reading.isHourlyAverage ? "Yes" : "No",
                            String(reading.sampleCount)
                        ]
                    }
                )
            )
        )

        let feeds = rooms.flatMap { $0.feedEvents }.sorted { $0.date < $1.date }
        files.append(
            CsvFile(
                name: "feed_events.csv",
                data: csvData(
                    headers: ["Date", "Room", "Kind", "Volume litres", "pH in", "EC in", "pH runoff", "EC runoff", "Note"],
                    rows: feeds.map { event in
                        [
                            timestamp(event.date),
                            event.room?.name ?? "",
                            event.kind.title,
                            numberText(event.volumeLiters),
                            numberText(event.phIn, digits: 1),
                            numberText(event.ecIn),
                            numberText(event.phRunoff, digits: 1),
                            numberText(event.ecRunoff),
                            event.note
                        ]
                    }
                )
            )
        )

        let calibrations = rooms.flatMap { $0.calibrationEvents }.sorted { $0.date < $1.date }
        files.append(
            CsvFile(
                name: "calibrations.csv",
                data: csvData(
                    headers: ["Date", "Room", "Meter", "Reading", "Next due", "Note"],
                    rows: calibrations.map { event in
                        [
                            timestamp(event.date),
                            event.room?.name ?? "",
                            event.meter.title,
                            numberText(event.reading),
                            event.nextDueDate.map(timestamp) ?? "",
                            event.note
                        ]
                    }
                )
            )
        )

        let lightEvents = rooms.flatMap { $0.lightScheduleEvents }.sorted { $0.date < $1.date }
        files.append(
            CsvFile(
                name: "light_schedule.csv",
                data: csvData(
                    headers: ["Date", "Room", "Previous on", "Previous off", "New on", "New off", "Flowering plants", "Note"],
                    rows: lightEvents.map { event in
                        [
                            timestamp(event.date),
                            event.room?.name ?? "",
                            LightSchedule.timeLabel(event.previousOnMinutes),
                            LightSchedule.timeLabel(event.previousOffMinutes),
                            LightSchedule.timeLabel(event.newOnMinutes),
                            LightSchedule.timeLabel(event.newOffMinutes),
                            event.hadFloweringPlants ? "Yes" : "No",
                            event.note
                        ]
                    }
                )
            )
        )

        files.append(
            CsvFile(
                name: "care_reminders.csv",
                data: csvData(
                    headers: ["Title", "Kind", "Time of day", "Repeat days", "Enabled", "Last completed", "Next due", "Room"],
                    rows: reminders.map { reminder in
                        [
                            reminder.title,
                            reminder.kind.title,
                            String(format: "%02d:%02d", reminder.timeOfDayMinutes / 60, reminder.timeOfDayMinutes % 60),
                            String(reminder.repeatDays),
                            reminder.isEnabled ? "Yes" : "No",
                            reminder.lastCompletedAt.map(timestamp) ?? "",
                            timestamp(reminder.nextDueDate),
                            reminder.room?.name ?? ""
                        ]
                    }
                )
            )
        )

        files.append(
            CsvFile(
                name: "drying_sessions.csv",
                data: csvData(
                    headers: [
                        "Plant", "Started", "Phase", "Profile", "Curing started", "Ended",
                        "Temperature low", "Temperature high", "Humidity low", "Humidity high", "Burp mode"
                    ],
                    rows: dryingSessions.map { session in
                        [
                            session.plant?.name ?? "",
                            timestamp(session.startedAt),
                            session.phase.title,
                            session.profile.title,
                            session.curingStartedAt.map(timestamp) ?? "",
                            session.endedAt.map(timestamp) ?? "",
                            numberText(session.targetTemperatureLow, digits: 1),
                            numberText(session.targetTemperatureHigh, digits: 1),
                            numberText(session.targetHumidityLow, digits: 0),
                            numberText(session.targetHumidityHigh, digits: 0),
                            session.burpMode.title
                        ]
                    }
                )
            )
        )

        let treatments = plants.flatMap(\.treatments) + rooms.flatMap(\.treatments)
        files.append(
            CsvFile(
                name: "treatments.csv",
                data: csvData(
                    headers: ["Date", "Product", "Dose", "Withdrawal days", "Note", "Plant", "Room"],
                    rows: treatments.map { treatment in
                        [timestamp(treatment.date), treatment.productName, treatment.dose, treatment.withdrawalDays.map(String.init) ?? "", treatment.note, treatment.plant?.name ?? "", treatment.room?.name ?? ""]
                    }
                )
            )
        )

        let equipment = rooms.flatMap(\.equipment)
        files.append(
            CsvFile(
                name: "equipment.csv",
                data: csvData(
                    headers: ["Name", "Room", "Service interval days", "Last serviced", "Next service"],
                    rows: equipment.map { item in
                        [item.name, item.room?.name ?? "", String(item.serviceIntervalDays), timestamp(item.lastServicedAt), timestamp(item.nextServiceDate)]
                    }
                )
            )
        )

        let serviceRecords = equipment.flatMap(\.serviceRecords)
        files.append(
            CsvFile(
                name: "service_history.csv",
                data: csvData(
                    headers: ["Date", "Equipment", "Note"],
                    rows: serviceRecords.map { record in [timestamp(record.date), record.equipment?.name ?? "", record.note] }
                )
            )
        )

        let scoutingChecks = plants.flatMap(\.scoutingChecks) + rooms.flatMap(\.scoutingChecks)
        files.append(
            CsvFile(
                name: "scouting_checks.csv",
                data: csvData(
                    headers: ["Date", "Findings", "Note", "Photo", "Plant", "Room"],
                    rows: scoutingChecks.map { check in [timestamp(check.date), check.findings.map(\.title).joined(separator: "; "), check.note, check.photoFileName ?? "", check.plant?.name ?? "", check.room?.name ?? ""] }
                )
            )
        )

        if options.includeJournal {
            files.append(
                CsvFile(
                    name: "journal.csv",
                    data: csvData(
                        headers: ["Date", "Kind", "Text", "Tag", "Plant", "Room", "Photo file"],
                        rows: journal.map { entry in
                            [
                                timestamp(entry.createdAt),
                                entry.kind.title,
                                entry.text,
                                entry.tag?.title ?? "",
                                entry.plant?.name ?? "",
                                entry.room?.name ?? "",
                                entry.photoFileName ?? ""
                            ]
                        }
                    )
                )
            )
        }

        let trainingSessions = plants.flatMap(\.trainingSessions).sorted { $0.date < $1.date }
        files.append(
            CsvFile(
                name: "training_sessions.csv",
                data: csvData(
                    headers: ["Date", "Method", "Nodes affected", "Note", "Plant"],
                    rows: trainingSessions.map { session in
                        [
                            timestamp(session.date),
                            session.methodRaw,
                            session.nodesAffected.map(String.init) ?? "",
                            session.note,
                            session.plant?.name ?? ""
                        ]
                    }
                )
            )
        )

        files.append(
            CsvFile(
                name: "feed_schedules.csv",
                data: csvData(
                    headers: ["Schedule", "Week", "Target pH", "Target EC", "Product", "ml per litre", "Applied rooms"],
                    rows: snapshot.feedSchedules.flatMap { schedule -> [[String]] in
                        let applied = schedule.sortedAppliedRooms.map(\.name).joined(separator: "; ")
                        return schedule.sortedWeeks.flatMap { week -> [[String]] in
                            let products = week.sortedProducts
                            guard !products.isEmpty else {
                                return [[
                                    schedule.name,
                                    String(week.weekNumber),
                                    numberText(week.targetPH, digits: 1),
                                    numberText(week.targetEC),
                                    "",
                                    "",
                                    applied
                                ]]
                            }
                            return products.map { product in
                                [
                                    schedule.name,
                                    String(week.weekNumber),
                                    numberText(week.targetPH, digits: 1),
                                    numberText(week.targetEC),
                                    product.name,
                                    numberText(product.doseMLPerLiter),
                                    applied
                                ]
                            }
                        }
                    }
                )
            )
        )

        files.append(
            CsvFile(
                name: "cycle_archives.csv",
                data: csvData(
                    headers: ["Name", "Completed", "Plants", "Rooms", "Dry yield grams"],
                    rows: snapshot.cycleArchives.map { archive in
                        [
                            archive.name,
                            timestamp(archive.completedAt),
                            archive.sortedPlants.map(\.name).joined(separator: "; "),
                            archive.roomSummary,
                            numberText(archive.dryYieldGrams)
                        ]
                    }
                )
            )
        )

        files.append(
            CsvFile(
                name: "sensors.csv",
                data: csvData(
                    headers: ["Name", "Transport", "Identifier", "Room", "Paired", "Last seen", "Connected"],
                    rows: snapshot.sensors.map { sensor in
                        [
                            sensor.name,
                            sensor.transport.title,
                            sensor.identifier,
                            sensor.room?.name ?? "",
                            timestamp(sensor.pairedAt),
                            sensor.lastSeenAt.map(timestamp) ?? "",
                            sensor.isConnected ? "Yes" : "No"
                        ]
                    }
                )
            )
        )

        files.append(
            CsvFile(
                name: "share_grants.csv",
                data: csvData(
                    headers: ["Recipient", "Rooms", "Plants", "Categories", "Created", "Expires", "Revoked", "Access log entries"],
                    rows: snapshot.shareGrants.map { grant in
                        [
                            grant.recipientName,
                            grant.roomNames.joined(separator: "; "),
                            grant.plantNames.joined(separator: "; "),
                            grant.categories.joined(separator: "; "),
                            timestamp(grant.createdAt),
                            timestamp(grant.expiresAt),
                            grant.revokedAt.map(timestamp) ?? "",
                            String(grant.accessLogs.count)
                        ]
                    }
                )
            )
        )

        files.append(
            CsvFile(
                name: "compliance_history.csv",
                data: csvData(
                    headers: [
                        "Captured", "Jurisdiction", "State", "Rule pack", "Rule verified",
                        "Counted plants", "Plant limit", "Stored flower grams",
                        "Stored flower limit grams", "Canopy square metres",
                        "Canopy limit square metres", "Overall", "Baseline"
                    ],
                    rows: snapshot.complianceSnapshots
                        .sorted { $0.capturedAt < $1.capturedAt }
                        .map { item in
                            [
                                timestamp(item.capturedAt),
                                item.jurisdictionCode,
                                item.stateName,
                                item.rulePackVersion,
                                item.ruleVerifiedOn,
                                String(item.countedPlantTotal),
                                item.plantLimit.map(String.init) ?? "",
                                numberText(item.retainedDryWeightGrams),
                                numberText(item.possessionLimitGrams),
                                numberText(item.canopySquareMeters),
                                numberText(item.canopyLimitSqM),
                                item.overallLevel.title,
                                item.isUpgradeBaseline ? "Yes" : "No"
                            ]
                        }
                )
            )
        )

        files.append(
            CsvFile(
                name: "rule_change_reviews.csv",
                data: csvData(
                    headers: [
                        "Evaluated", "Jurisdiction", "Prior pack", "New pack",
                        "Outcome", "Summary", "Acknowledged"
                    ],
                    rows: snapshot.ruleEvaluationEvents
                        .sorted { $0.evaluatedAt < $1.evaluatedAt }
                        .map { event in
                            [
                                timestamp(event.evaluatedAt),
                                event.jurisdictionCode,
                                event.priorPackVersion,
                                event.newPackVersion,
                                event.outcome.rawValue,
                                event.changedSummary,
                                event.acknowledgedAt.map(timestamp) ?? ""
                            ]
                        }
                )
            )
        )

        return files
    }

    private static func csvData(headers: [String], rows: [[String]]) -> Data {
        var lines = [headers.map(escaped).joined(separator: ",")]
        for row in rows {
            lines.append(row.map(escaped).joined(separator: ","))
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    private static func escaped(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func numberText(_ value: Double?, digits: Int = 2) -> String {
        guard let value else { return "" }
        return String(format: "%.\(digits)f", value)
    }

    private static func timestamp(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    // MARK: - Encryption

    static let currentFormatVersion = 2

    static let currentBackupVersion = 2

    private static let exportHeaderV2 = Data("GROWENC2".utf8)
    private static let backupHeaderV2 = Data("GROWBACK2".utf8)
    private static let backupHeaderV1 = Data("GROWBACK1".utf8)
    private static let backupHeaderFamily = Data("GROWBACK".utf8)

    /// 1 is PBKDF2-HMAC-SHA256. It is written into the envelope so the cost can
    /// change later without stranding archives that were already made.
    private static let kdfIdentifier: UInt8 = 1

    private static let saltByteCount = 16
    private static let legacyIterations = 100_000
    private static let iterations = 210_000

    /// Bounded so a tampered header cannot make the key derivation run for minutes.
    private static let acceptedIterations = 10_000...2_000_000

    static func buildBackup(
        snapshot: ExportSnapshot,
        includeJournal: Bool,
        includePhotos: Bool,
        password: String
    ) throws -> Data {
        guard !password.isEmpty else { throw ExportServiceError.encryptionFailed }

        let data = try jsonData(
            snapshot: snapshot,
            options: ExportOptions(
                includeJournal: includeJournal,
                includePhotos: includePhotos,
                password: nil
            )
        )
        guard var document = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExportServiceError.encryptionFailed
        }

        if includeJournal && includePhotos {
            let photos = snapshot.journal.compactMap { entry -> [String: Any]? in
                guard let fileName = entry.photoFileName,
                      let image = try? Data(contentsOf: PhotoStore.url(for: fileName)) else { return nil }
                return ["fileName": fileName, "data": image.base64EncodedString()]
            }
            document["photos"] = photos
        }

        return try encodeBackup(document, password: password, formatVersion: currentBackupVersion)
    }

    /// Wraps an already-built backup document in the encrypted envelope.
    /// Version 1 is the legacy envelope: it stays writable so the older format
    /// remains covered by tests, and restore reads both versions.
    static func encodeBackup(_ root: [String: Any], password: String, formatVersion: Int) throws -> Data {
        guard !password.isEmpty else { throw ExportServiceError.encryptionFailed }
        guard formatVersion == 1 || formatVersion == currentBackupVersion else {
            throw ExportServiceError.unsupportedBackupVersion
        }

        var document = root
        document["backupVersion"] = formatVersion
        if formatVersion >= 2 {
            document["formatVersion"] = currentFormatVersion
        }

        let data = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])

        if formatVersion == 1 {
            return try sealLegacy(data, password: password, header: backupHeaderV1)
        }
        return try seal(data, password: password, header: backupHeaderV2)
    }

    static func decodeBackup(_ data: Data, password: String) throws -> [String: Any] {
        let version = try envelopeVersion(of: data)

        let snapshot: Data
        if version == 1 {
            snapshot = try openLegacy(data, password: password, header: backupHeaderV1)
        } else {
            snapshot = try open(data, password: password, header: backupHeaderV2)
        }

        guard let root = try JSONSerialization.jsonObject(with: snapshot) as? [String: Any] else {
            throw ExportServiceError.invalidBackup("the file does not contain a backup document")
        }
        guard let documentVersion = root["backupVersion"] as? Int else {
            throw ExportServiceError.invalidBackup("the backup has no version number")
        }
        guard documentVersion == version else {
            throw ExportServiceError.invalidBackup("the envelope and the document disagree about the version")
        }
        guard documentVersion <= currentBackupVersion else {
            throw ExportServiceError.unsupportedBackupVersion
        }

        return root
    }

    /// What a backup holds, so restore can summarise it before replacing anything.
    struct BackupSummary {
        let version: Int
        let createdAt: Date?
        let counts: [String: Int]
        let includesPhotos: Bool

        var totalRecords: Int { DataInventory.total(of: counts) }
    }

    static func summarize(_ root: [String: Any]) throws -> BackupSummary {
        guard let version = root["backupVersion"] as? Int, version <= currentBackupVersion else {
            throw ExportServiceError.unsupportedBackupVersion
        }

        var counts: [String: Int] = [:]
        if let manifest = root["manifest"] as? [String: Any],
           let stored = manifest["counts"] as? [String: Any] {
            for (key, value) in stored {
                if let number = value as? Int { counts[key] = number }
            }
        }

        // A version 1 backup carries no manifest; count the top-level lists so
        // the replace summary still states something true.
        if counts.isEmpty {
            let fallback: [(model: String, key: String)] = [
                ("Room", "rooms"),
                ("Plant", "plants"),
                ("Strain", "strains"),
                ("CareReminder", "careReminders"),
                ("DryingSession", "dryingSessions"),
                ("JournalEntry", "journal"),
                ("FeedSchedule", "feedSchedules"),
                ("CycleArchive", "cycleArchives"),
                ("SensorDevice", "sensors"),
                ("ShareGrant", "shareGrants")
            ]
            for entry in fallback {
                counts[entry.model] = (root[entry.key] as? [[String: Any]])?.count ?? 0
            }
        }

        let photos = root["photos"] as? [[String: Any]] ?? []

        return BackupSummary(
            version: version,
            createdAt: (root["exportedAt"] as? String).flatMap { isoFormatter.date(from: $0) },
            counts: counts,
            includesPhotos: !photos.isEmpty
        )
    }

    private static func envelopeVersion(of data: Data) throws -> Int {
        if hasPrefix(data, backupHeaderV1) { return 1 }
        if hasPrefix(data, backupHeaderV2) { return 2 }
        if hasPrefix(data, backupHeaderFamily) {
            throw ExportServiceError.unsupportedBackupVersion
        }
        throw ExportServiceError.invalidBackup("it is not a Grow Companion backup")
    }

    private static func hasPrefix(_ data: Data, _ prefix: Data) -> Bool {
        guard data.count >= prefix.count else { return false }
        return Data(data.prefix(prefix.count)) == prefix
    }

    private static func seal(_ data: Data, password: String, header: Data) throws -> Data {
        let salt = randomBytes(count: saltByteCount)
        guard salt.count == saltByteCount else { throw ExportServiceError.encryptionFailed }

        let key = SymmetricKey(data: pbkdf2SHA256(
            password: Data(password.utf8),
            salt: salt,
            iterations: iterations,
            outputByteCount: 32
        ))

        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw ExportServiceError.encryptionFailed }

        var output = header
        output.append(kdfIdentifier)
        output.appendBigEndian(UInt32(iterations))
        output.append(UInt8(saltByteCount))
        output.append(salt)
        output.append(combined)
        return output
    }

    private static func sealLegacy(_ data: Data, password: String, header: Data) throws -> Data {
        let salt = randomBytes(count: saltByteCount)
        guard salt.count == saltByteCount else { throw ExportServiceError.encryptionFailed }

        let key = SymmetricKey(data: pbkdf2SHA256(
            password: Data(password.utf8),
            salt: salt,
            iterations: legacyIterations,
            outputByteCount: 32
        ))

        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw ExportServiceError.encryptionFailed }

        var output = header
        output.append(salt)
        output.append(combined)
        return output
    }

    private static func open(_ data: Data, password: String, header: Data) throws -> Data {
        guard hasPrefix(data, header) else {
            throw ExportServiceError.invalidBackup("the envelope header is missing")
        }

        let headerEnd = header.count
        let parametersEnd = header.count + 1 + 4 + 1
        guard data.count > parametersEnd else {
            throw ExportServiceError.invalidBackup("the envelope is truncated")
        }

        let start = data.startIndex
        guard data[start + headerEnd] == kdfIdentifier else {
            throw ExportServiceError.invalidBackup("the backup uses an unknown key-derivation function")
        }

        let iterationCount = readBigEndianUInt32(data, at: headerEnd + 1)
        guard acceptedIterations.contains(Int(iterationCount)) else {
            throw ExportServiceError.invalidBackup("the backup's key-derivation cost is out of range")
        }

        let saltLength = Int(data[start + headerEnd + 5])
        guard saltLength == saltByteCount, data.count > parametersEnd + saltLength else {
            throw ExportServiceError.invalidBackup("the envelope is truncated")
        }

        let salt = slice(data, from: parametersEnd, length: saltLength)
        let combined = suffix(data, from: parametersEnd + saltLength)
        let key = SymmetricKey(data: pbkdf2SHA256(
            password: Data(password.utf8),
            salt: salt,
            iterations: Int(iterationCount),
            outputByteCount: 32
        ))

        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw ExportServiceError.encryptionFailed
        }
    }

    private static func openLegacy(_ data: Data, password: String, header: Data) throws -> Data {
        guard hasPrefix(data, header) else {
            throw ExportServiceError.invalidBackup("the envelope header is missing")
        }
        guard data.count > header.count + saltByteCount else {
            throw ExportServiceError.invalidBackup("the envelope is truncated")
        }

        let salt = slice(data, from: header.count, length: saltByteCount)
        let combined = suffix(data, from: header.count + saltByteCount)
        let key = SymmetricKey(data: pbkdf2SHA256(
            password: Data(password.utf8),
            salt: salt,
            iterations: legacyIterations,
            outputByteCount: 32
        ))

        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw ExportServiceError.encryptionFailed
        }
    }

    private static func slice(_ data: Data, from offset: Int, length: Int) -> Data {
        let start = data.startIndex + offset
        return Data(data[start..<(start + length)])
    }

    private static func suffix(_ data: Data, from offset: Int) -> Data {
        Data(data[(data.startIndex + offset)...])
    }

    private static func readBigEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let start = data.startIndex + offset
        var value: UInt32 = 0
        for index in 0..<4 {
            value = (value << 8) | UInt32(data[start + index])
        }
        return value
    }

    private static func pbkdf2SHA256(password: Data, salt: Data, iterations: Int, outputByteCount: Int) -> Data {
        let key = SymmetricKey(data: password)
        var derived = Data()
        var blockIndex: UInt32 = 1

        while derived.count < outputByteCount {
            var message = salt
            message.append(UInt8((blockIndex >> 24) & 0xff))
            message.append(UInt8((blockIndex >> 16) & 0xff))
            message.append(UInt8((blockIndex >> 8) & 0xff))
            message.append(UInt8(blockIndex & 0xff))

            var block = Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
            var accumulator = block
            if iterations > 1 {
                for _ in 2...iterations {
                    block = Data(HMAC<SHA256>.authenticationCode(for: block, using: key))
                    for index in accumulator.indices {
                        accumulator[index] ^= block[index]
                    }
                }
            }
            derived.append(accumulator)
            blockIndex += 1
        }

        return Data(derived.prefix(outputByteCount))
    }

    private static func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { return Data() }
        return Data(bytes)
    }

    // MARK: - Delete everything

    /// Removes every record, photo, pending notification and preference the app
    /// owns. Throws rather than reporting a success it could not verify, and
    /// rolls the context back so the records survive a failed attempt.
    @discardableResult
    static func deleteEverything(context: ModelContext, appLock: AppLock) throws -> [String: Int] {
        CareNotifications.cancelAll()
        PhotoStore.deleteAll()
        WidgetSnapshotStore.clear()
        DataControlPreferences.resetToDefaults()
        DeviceKeyStore.deleteAll()

        let remaining: [String: Int]
        do {
            remaining = try DataInventory.deleteAll(in: context)
        } catch {
            context.rollback()
            throw ExportServiceError.deletionFailed(error.localizedDescription)
        }

        appLock.resetForDataErase()
        return remaining
    }

    // MARK: - Small pieces

    private static func boxed(_ value: Double?) -> Any {
        guard let value else { return NSNull() }
        return value
    }

    private static func boxed(_ value: Int?) -> Any {
        guard let value else { return NSNull() }
        return value
    }

    private static func iso(_ date: Date?) -> Any {
        guard let date else { return NSNull() }
        return isoFormatter.string(from: date)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: Date())
    }

    private static let readme = """
    Grow Companion export
    =====================

    grow-companion.json  Everything in one file: profile, rooms, plants with
                         their stage history, strains, feed schedules, cycle
                         archives, sensors, sharing configurations, reminders,
                         environment readings, feeds, calibrations, light
                         schedule changes, treatments, equipment and service
                         history, scouting, drying and curing sessions, and the
                         journal when it was included. It also holds the
                         compliance history snapshots and their rule change
                         reviews, so a change to the rules can be explained from
                         the record itself. Its manifest states the format
                         version, the model list and the record count for every
                         supported record type.

    csv/                 One spreadsheet-friendly file per record type.

    photos/              Journal photos, when they were included.

    All dates are ISO 8601. Missing numbers are empty in CSV and null in JSON.
    """
}

extension Data {
    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var big = value.bigEndian
        let bytes = Swift.withUnsafeBytes(of: &big) { Array($0) }
        append(contentsOf: bytes)
    }
}
