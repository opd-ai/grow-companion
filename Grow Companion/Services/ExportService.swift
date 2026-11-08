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

struct ExportSummary {
    let plants: Int
    let rooms: Int
    let strains: Int
    let journalEntries: Int
    let photos: Int
    let reminders: Int
}

enum ExportServiceError: LocalizedError {
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "The password-protected archive could not be created."
        }
    }
}

enum ExportService {
    // MARK: - Build

    static func build(
        profile: GrowProfile?,
        rooms: [Room],
        plants: [Plant],
        strains: [Strain],
        reminders: [CareReminder],
        dryingSessions: [DryingSession],
        journal: [JournalEntry],
        options: ExportOptions
    ) throws -> ExportPayload {
        var archive = SimpleZipArchive()

        let json = try jsonData(
            profile: profile,
            rooms: rooms,
            plants: plants,
            strains: strains,
            reminders: reminders,
            dryingSessions: dryingSessions,
            journal: journal,
            options: options
        )
        archive.add(json, as: "grow-companion.json")

        for file in csvFiles(
            rooms: rooms,
            plants: plants,
            strains: strains,
            reminders: reminders,
            dryingSessions: dryingSessions,
            journal: journal,
            options: options
        ) {
            archive.add(file.data, as: "csv/\(file.name)")
        }

        if options.includeJournal && options.includePhotos {
            for entry in journal {
                guard let fileName = entry.photoFileName else { continue }
                guard let data = try? Data(contentsOf: PhotoStore.url(for: fileName)) else { continue }
                archive.add(data, as: "photos/\(fileName)")
            }
        }

        archive.add(Data(readme.utf8), as: "README.txt")

        let zip = archive.makeData()
        let stamp = fileStamp()

        if let password = options.password, !password.isEmpty {
            let encrypted = try encrypt(zip, password: password)
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

    private static func jsonData(
        profile: GrowProfile?,
        rooms: [Room],
        plants: [Plant],
        strains: [Strain],
        reminders: [CareReminder],
        dryingSessions: [DryingSession],
        journal: [JournalEntry],
        options: ExportOptions
    ) throws -> Data {
        let readings = rooms.flatMap { $0.environmentReadings }.sorted { $0.date < $1.date }
        let feeds = rooms.flatMap { $0.feedEvents }.sorted { $0.date < $1.date }
        let calibrations = rooms.flatMap { $0.calibrationEvents }.sorted { $0.date < $1.date }
        let lightEvents = rooms.flatMap { $0.lightScheduleEvents }.sorted { $0.date < $1.date }
        let treatments = plants.flatMap(\.treatments) + rooms.flatMap(\.treatments)
        let equipment = rooms.flatMap(\.equipment)
        let serviceRecords = equipment.flatMap(\.serviceRecords)
        let scoutingChecks = plants.flatMap(\.scoutingChecks) + rooms.flatMap(\.scoutingChecks)
        let environmentAlerts = rooms.flatMap(\.environmentAlerts)

        let profileValue: Any = profile.map { profileDictionary($0) as Any } ?? NSNull()

        let root: [String: Any] = [
            "app": "Grow Companion",
            "formatVersion": 1,
            "exportedAt": iso(Date()),
            "unitSystem": UserDefaults.standard.string(forKey: SettingsKey.unitSystem) ?? "metric",
            "options": [
                "journal": options.includeJournal,
                "photos": options.includePhotos
            ],
            "profile": profileValue,
            "rooms": rooms.map(roomDictionary),
            "plants": plants.map(plantDictionary),
            "strains": strains.map(strainDictionary),
            "careReminders": reminders.map(reminderDictionary),
            "environmentReadings": readings.map(readingDictionary),
            "feedEvents": feeds.map(feedDictionary),
            "calibrations": calibrations.map(calibrationDictionary),
            "lightScheduleEvents": lightEvents.map(lightDictionary),
            "dryingSessions": dryingSessions.map(dryingDictionary),
            "treatments": treatments.map(treatmentDictionary),
            "equipment": equipment.map(equipmentDictionary),
            "serviceRecords": serviceRecords.map(serviceRecordDictionary),
            "scoutingChecks": scoutingChecks.map(scoutingDictionary),
            "environmentAlerts": environmentAlerts.map(environmentAlertDictionary),
            "journal": options.includeJournal ? journal.map(journalDictionary) : []
        ]

        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
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
            "canopySquareMeters": boxed(room.canopySquareMeters),
            "feedTargetPH": boxed(room.feedTargetPH),
            "feedTargetEC": boxed(room.feedTargetEC),
            "lightsOnMinutes": room.lightsOnMinutes,
            "lightsOffMinutes": room.lightsOffMinutes,
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
            "notes": strain.notes,
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

    // MARK: - CSV

    private struct CsvFile {
        let name: String
        let data: Data
    }

    private static func csvFiles(
        rooms: [Room],
        plants: [Plant],
        strains: [Strain],
        reminders: [CareReminder],
        dryingSessions: [DryingSession],
        journal: [JournalEntry],
        options: ExportOptions
    ) -> [CsvFile] {
        var files: [CsvFile] = []

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

    static func buildBackup(
        profile: GrowProfile?,
        rooms: [Room],
        plants: [Plant],
        strains: [Strain],
        reminders: [CareReminder],
        dryingSessions: [DryingSession],
        journal: [JournalEntry],
        includePhotos: Bool,
        password: String
    ) throws -> Data {
        guard !password.isEmpty else { throw ExportServiceError.encryptionFailed }
        let data = try jsonData(
            profile: profile,
            rooms: rooms,
            plants: plants,
            strains: strains,
            reminders: reminders,
            dryingSessions: dryingSessions,
            journal: journal,
            options: ExportOptions(includeJournal: includePhotos, includePhotos: includePhotos, password: nil)
        )
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExportServiceError.encryptionFailed
        }
        root["backupVersion"] = 1
        if includePhotos {
            let photos = journal.compactMap { entry -> [String: Any]? in
                guard let fileName = entry.photoFileName,
                      let image = try? Data(contentsOf: PhotoStore.url(for: fileName)) else { return nil }
                return ["fileName": fileName, "data": image.base64EncodedString()]
            }
            root["photos"] = photos
        }
        let snapshot = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        return try encrypt(snapshot, password: password, header: "GROWBACK1")
    }

    static func decodeBackup(_ data: Data, password: String) throws -> [String: Any] {
        let snapshot = try decrypt(data, password: password, header: "GROWBACK1")
        guard let root = try JSONSerialization.jsonObject(with: snapshot) as? [String: Any],
              (root["backupVersion"] as? Int) == 1 else {
            throw ExportServiceError.encryptionFailed
        }
        return root
    }

    private static func encrypt(_ data: Data, password: String, header: String = "GROWENC1") throws -> Data {
        let salt = randomBytes(count: 16)
        let key = SymmetricKey(data: pbkdf2SHA256(
            password: Data(password.utf8),
            salt: salt,
            iterations: 100_000,
            outputByteCount: 32
        ))

        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw ExportServiceError.encryptionFailed
        }

        var output = Data(header.utf8)
        output.append(salt)
        output.append(combined)
        return output
    }

    private static func decrypt(_ data: Data, password: String, header: String) throws -> Data {
        let headerData = Data(header.utf8)
        guard data.count > headerData.count + 16,
              data.prefix(headerData.count) == headerData else {
            throw ExportServiceError.encryptionFailed
        }
        let saltStart = headerData.count
        let salt = data.subdata(in: saltStart..<(saltStart + 16))
        let combined = data.subdata(in: (saltStart + 16)..<data.count)
        let key = SymmetricKey(data: pbkdf2SHA256(password: Data(password.utf8), salt: salt, iterations: 100_000, outputByteCount: 32))
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw ExportServiceError.encryptionFailed
        }
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

    static func deleteEverything(context: ModelContext, appLock: AppLock) {
        CareNotifications.cancelAll()
        PhotoStore.deleteAll()
        NotificationSettings.resetToDefaults()

        let deletions: [() throws -> Void] = [
            { try context.delete(model: DryingCheck.self) },
            { try context.delete(model: CureBurp.self) },
            { try context.delete(model: DryingSession.self) },
            { try context.delete(model: TrainingSession.self) },
            { try context.delete(model: ScoutingCheck.self) },
            { try context.delete(model: EnvironmentAlert.self) },
            { try context.delete(model: ServiceRecord.self) },
            { try context.delete(model: Equipment.self) },
            { try context.delete(model: Treatment.self) },
            { try context.delete(model: FeedProduct.self) },
            { try context.delete(model: FeedWeek.self) },
            { try context.delete(model: FeedSchedule.self) },
            { try context.delete(model: StageEvent.self) },
            { try context.delete(model: JournalEntry.self) },
            { try context.delete(model: EnvironmentReading.self) },
            { try context.delete(model: FeedEvent.self) },
            { try context.delete(model: CalibrationEvent.self) },
            { try context.delete(model: LightScheduleEvent.self) },
            { try context.delete(model: CareReminder.self) },
            { try context.delete(model: Plant.self) },
            { try context.delete(model: Room.self) },
            { try context.delete(model: Strain.self) },
            { try context.delete(model: GrowProfile.self) }
        ]

        for deletion in deletions {
            try? deletion()
        }
        try? context.save()

        appLock.resetForDataErase()
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
                         their stage history, strains, reminders, environment
                         readings, feeds, calibrations, light schedule
                         changes, drying and curing sessions, and the journal
                         when it was included.

    csv/                 One spreadsheet-friendly file per record type.

    photos/              Journal photos, when they were included.

    All dates are ISO 8601. Missing numbers are empty in CSV and null in JSON.
    """
}
