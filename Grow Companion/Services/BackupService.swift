//
//  BackupService.swift
//  Grow Companion
//
//  Local, password-protected backup restore. Every model the app stores is
//  restored, and the whole restore is rehearsed in a throwaway in-memory store
//  before the device's records are replaced, so a damaged backup cannot cost
//  the grower the data that is still on the device.
//

import Foundation
import SwiftData

enum BackupService {
    /// Optional top-level arrays a backup may carry. Anything that is present
    /// has to be a list of records, and nothing is touched when it is not.
    private static let sectionKeys = [
        "strains", "careReminders", "environmentReadings", "feedEvents",
        "calibrations", "lightScheduleEvents", "dryingSessions", "treatments",
        "equipment", "serviceRecords", "scoutingChecks", "environmentAlerts",
        "trainingSessions", "feedSchedules", "cycleArchives", "sensors",
        "shareGrants", "complianceSnapshots", "ruleEvaluationEvents", "goals",
        "journal", "photos"
    ]

    /// Checks a decoded backup before anything on this device is touched.
    static func validate(_ root: [String: Any]) throws {
        guard let version = root["backupVersion"] as? Int else {
            throw ExportServiceError.invalidBackup("the backup has no version number")
        }
        guard version <= ExportService.currentBackupVersion else {
            throw ExportServiceError.unsupportedBackupVersion
        }

        _ = try arrays("rooms", in: root)
        _ = try arrays("plants", in: root)
        for key in sectionKeys {
            _ = try arrays(key, in: root)
        }

        try validateManifest(root)
    }

    /// Replaces the device's records with the backup's, after rehearsing the
    /// whole restore in a temporary store.
    static func restore(_ root: [String: Any], context: ModelContext, appLock: AppLock) throws -> RestoreReport {
        try validate(root)

        guard let version = root["backupVersion"] as? Int else {
            throw ExportServiceError.invalidBackup("the backup has no version number")
        }

        // Rehearse. Every insert and the save have to succeed here first.
        let stagingContainer: ModelContainer
        do {
            stagingContainer = try ModelContainer(
                for: DataInventory.schema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
        } catch {
            throw ExportServiceError.invalidBackup("a temporary store could not be opened to check the backup")
        }
        let stagingContext = ModelContext(stagingContainer)
        _ = try performRestore(root, context: stagingContext, writePhotos: false)

        // Replace. The lock and its grace period belong to the device, not the
        // backup, so they are put back afterwards.
        let lockEnabled = appLock.isEnabled
        let lockGrace = appLock.grace

        try ExportService.deleteEverything(context: context, appLock: appLock)

        appLock.grace = lockGrace
        appLock.isEnabled = lockEnabled

        do {
            let inserted = try performRestore(root, context: context, writePhotos: true)
            return RestoreReport(backupVersion: version, inserted: inserted)
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - Validation helpers

    private static func arrays(_ key: String, in root: [String: Any]) throws -> [[String: Any]] {
        guard let value = root[key] else { return [] }
        guard let list = value as? [[String: Any]] else {
            throw ExportServiceError.invalidBackup("the \(key) section is not a list of records")
        }
        return list
    }

    /// When a backup carries a v2 manifest, the counts it advertises for whole
    /// record types have to match the records actually in the file.
    private static func validateManifest(_ root: [String: Any]) throws {
        guard let manifest = root["manifest"] as? [String: Any],
              let stored = manifest["counts"] as? [String: Any] else { return }

        let checks: [(name: String, count: Int)] = [
            ("Room", try arrays("rooms", in: root).count),
            ("Plant", try arrays("plants", in: root).count),
            ("Strain", try arrays("strains", in: root).count),
            ("FeedSchedule", try arrays("feedSchedules", in: root).count),
            ("CycleArchive", try arrays("cycleArchives", in: root).count),
            ("SensorDevice", try arrays("sensors", in: root).count),
            ("ShareGrant", try arrays("shareGrants", in: root).count),
            ("ComplianceSnapshot", try arrays("complianceSnapshots", in: root).count),
            ("RuleEvaluationEvent", try arrays("ruleEvaluationEvents", in: root).count),
            ("GrowGoal", try arrays("goals", in: root).count)
        ]

        for check in checks {
            guard let raw = stored[check.name] else { continue }
            guard let recorded = raw as? Int, recorded == check.count else {
                throw ExportServiceError.invalidBackup("the manifest counts \(check.name) records that are not in the file")
            }
        }
    }

    // MARK: - Restore

    private static func performRestore(
        _ root: [String: Any],
        context: ModelContext,
        writePhotos: Bool
    ) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        func count(_ name: String, _ amount: Int = 1) {
            counts[name, default: 0] += amount
        }

        let roomsValue = try arrays("rooms", in: root)
        let plantsValue = try arrays("plants", in: root)

        // Profile
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
            count("GrowProfile")
        }

        // Feed schedules, so rooms can point at them.
        var feedScheduleByName: [String: FeedSchedule] = [:]
        for value in try arrays("feedSchedules", in: root) {
            let schedule = FeedSchedule(
                name: string(value["name"]),
                weekCount: value["weekCount"] as? Int ?? 8,
                createdAt: date(value["createdAt"]) ?? Date()
            )
            context.insert(schedule)
            feedScheduleByName[schedule.name] = schedule
            count("FeedSchedule")

            for weekValue in value["weeks"] as? [[String: Any]] ?? [] {
                let week = FeedWeek(
                    weekNumber: weekValue["weekNumber"] as? Int ?? 1,
                    targetPH: number(weekValue["targetPH"]),
                    targetEC: number(weekValue["targetEC"]),
                    schedule: schedule
                )
                context.insert(week)
                count("FeedWeek")

                for productValue in weekValue["products"] as? [[String: Any]] ?? [] {
                    let product = FeedProduct(
                        name: string(productValue["name"]),
                        doseMLPerLiter: number(productValue["doseMLPerLiter"]),
                        sortIndex: productValue["sortIndex"] as? Int ?? 0,
                        week: week
                    )
                    context.insert(product)
                    count("FeedProduct")
                }
            }
        }

        // Rooms
        var roomByName: [String: Room] = [:]
        for value in roomsValue {
            let room = Room(
                name: string(value["name"]),
                type: RoomType(rawValue: string(value["type"])) ?? .tent,
                isIndoor: value["isIndoor"] as? Bool ?? true,
                lightType: string(value["lightType"]),
                lightWatts: value["lightWatts"] as? Int ?? 0,
                lightFixture: LightFixtureType(rawValue: string(value["lightFixture"])) ?? .led,
                canopySquareMeters: number(value["canopySquareMeters"]),
                canopyDistanceMeters: number(value["canopyDistanceMeters"]),
                canopyDistanceMeasuredAt: date(value["canopyDistanceMeasuredAt"]),
                canopyDistanceSource: LightDistanceSource(rawValue: string(value["canopyDistanceSource"])),
                lightsOnMinutes: value["lightsOnMinutes"] as? Int ?? 360,
                lightsOffMinutes: value["lightsOffMinutes"] as? Int ?? 0,
                createdAt: date(value["createdAt"]) ?? Date()
            )
            room.feedTargetPH = number(value["feedTargetPH"])
            room.feedTargetEC = number(value["feedTargetEC"])
            room.sustainedAlertMinutes = value["sustainedAlertMinutes"] as? Int ?? 10
            room.feedSchedule = feedScheduleByName[string(value["feedSchedule"])]
            room.feedScheduleStartDate = date(value["feedScheduleStartDate"])
            context.insert(room)
            roomByName[room.name] = room
            count("Room")
        }

        // Cycle archives, so plants can point at them.
        var archiveByName: [String: CycleArchive] = [:]
        for value in try arrays("cycleArchives", in: root) {
            let archive = CycleArchive(
                name: string(value["name"]),
                completedAt: date(value["completedAt"]) ?? Date()
            )
            context.insert(archive)
            archiveByName[archive.name] = archive
            count("CycleArchive")
        }

        // Strains
        var strainByName: [String: Strain] = [:]
        for value in try arrays("strains", in: root) {
            let strain = Strain(
                name: string(value["name"]),
                breeder: string(value["breeder"]),
                type: StrainType(rawValue: string(value["type"])) ?? .hybrid,
                expectedFloweringWeeks: value["expectedFloweringWeeks"] as? Int ?? 9,
                claimedYield: string(value["claimedYield"]),
                parentLines: string(value["parentLines"]),
                lineageStatus: LineageStatus(rawValue: string(value["lineageStatus"])) ?? .missing,
                breederSource: string(value["breederSource"]),
                notes: string(value["notes"]),
                createdAt: date(value["createdAt"]) ?? Date()
            )
            context.insert(strain)
            strainByName[strain.name] = strain
            count("Strain")
        }

        // Plants and their stage history
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
            plant.ratedAt = date(value["ratedAt"])
            plant.cycleArchive = archiveByName[string(value["cycleArchive"])]
            context.insert(plant)
            plantByName[plant.name] = plant
            count("Plant")

            for eventValue in value["stageHistory"] as? [[String: Any]] ?? [] {
                let event = StageEvent(
                    stage: PlantStage(rawValue: string(eventValue["stage"])) ?? plant.stage,
                    date: date(eventValue["date"]) ?? plant.plantedAt,
                    note: string(eventValue["note"]),
                    isBackfilled: eventValue["backfilled"] as? Bool ?? false,
                    plant: plant
                )
                context.insert(event)
                count("StageEvent")
            }
        }

        // Lineage, once every plant exists.
        for value in plantsValue {
            guard let plant = plantByName[string(value["name"])] else { continue }
            if let mother = plantByName[string(value["mother"])] {
                plant.mother = mother
            }
        }

        // Sensors, before the readings that may point at them.
        var sensorByName: [String: SensorDevice] = [:]
        for value in try arrays("sensors", in: root) {
            let sensor = SensorDevice(
                name: string(value["name"]),
                identifier: string(value["identifier"]),
                transport: SensorTransport(rawValue: string(value["transport"])) ?? .bluetooth,
                pairedAt: date(value["pairedAt"]) ?? Date(),
                room: roomByName[string(value["room"])]
            )
            sensor.lastSeenAt = date(value["lastSeenAt"])
            sensor.lastReadingAt = date(value["lastReadingAt"])
            sensor.isConnected = value["isConnected"] as? Bool ?? false
            context.insert(sensor)
            sensorByName[sensor.name] = sensor
            count("SensorDevice")
        }

        // Training
        for value in try arrays("trainingSessions", in: root) {
            let session = TrainingSession(
                method: TrainingMethod(rawValue: string(value["method"])) ?? .topping,
                date: date(value["date"]) ?? Date(),
                nodesAffected: value["nodesAffected"] as? Int,
                note: string(value["note"]),
                plant: plantByName[string(value["plant"])]
            )
            context.insert(session)
            count("TrainingSession")
        }

        // Treatments
        for value in try arrays("treatments", in: root) {
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
            count("Treatment")
        }

        // Equipment and service history
        var equipmentByName: [String: Equipment] = [:]
        for value in try arrays("equipment", in: root) {
            let item = Equipment(
                name: string(value["name"]),
                serviceIntervalDays: value["serviceIntervalDays"] as? Int ?? 90,
                lastServicedAt: date(value["lastServicedAt"]) ?? Date(),
                room: roomByName[string(value["room"])]
            )
            context.insert(item)
            equipmentByName[item.name] = item
            count("Equipment")
        }
        for value in try arrays("serviceRecords", in: root) {
            let record = ServiceRecord(
                date: date(value["date"]) ?? Date(),
                note: string(value["note"]),
                equipment: equipmentByName[string(value["equipment"])]
            )
            context.insert(record)
            count("ServiceRecord")
        }

        // Scouting
        for value in try arrays("scoutingChecks", in: root) {
            let photoName = string(value["photo"])
            let check = ScoutingCheck(
                date: date(value["date"]) ?? Date(),
                findings: (value["findings"] as? [String] ?? []).compactMap(ObservationTag.init(rawValue:)),
                note: string(value["note"]),
                photoFileName: photoName.isEmpty ? nil : photoName,
                plant: plantByName[string(value["plant"])],
                room: roomByName[string(value["room"])]
            )
            context.insert(check)
            count("ScoutingCheck")
        }

        // Environment readings
        for value in try arrays("environmentReadings", in: root) {
            let reading = EnvironmentReading(
                date: date(value["date"]) ?? Date(),
                temperatureC: number(value["temperatureC"]),
                humidityPercent: number(value["humidityPercent"]),
                lightPPFD: number(value["lightPPFD"]),
                isHourlyAverage: value["isHourlyAverage"] as? Bool ?? false,
                sampleCount: value["sampleCount"] as? Int ?? 1,
                source: EnvironmentReadingSource(rawValue: string(value["source"])) ?? .manual,
                room: roomByName[string(value["room"])],
                sensor: sensorByName[string(value["sensor"])]
            )
            context.insert(reading)
            count("EnvironmentReading")
        }

        // Feed events
        for value in try arrays("feedEvents", in: root) {
            let event = FeedEvent(
                date: date(value["date"]) ?? Date(),
                kind: FeedKind(rawValue: string(value["kind"])) ?? .water,
                volumeLiters: number(value["volumeLiters"]),
                phIn: number(value["phIn"]),
                ecIn: number(value["ecIn"]),
                phRunoff: number(value["phRunoff"]),
                ecRunoff: number(value["ecRunoff"]),
                note: string(value["note"]),
                room: roomByName[string(value["room"])]
            )
            context.insert(event)
            count("FeedEvent")
        }

        // Calibrations
        for value in try arrays("calibrations", in: root) {
            let event = CalibrationEvent(
                date: date(value["date"]) ?? Date(),
                meter: CalibrationMeter(rawValue: string(value["meter"])) ?? .phMeter,
                reading: number(value["reading"]),
                note: string(value["note"]),
                nextDueDate: date(value["nextDueDate"]),
                room: roomByName[string(value["room"])]
            )
            context.insert(event)
            count("CalibrationEvent")
        }

        // Light schedule changes
        for value in try arrays("lightScheduleEvents", in: root) {
            let event = LightScheduleEvent(
                date: date(value["date"]) ?? Date(),
                previousOnMinutes: value["previousOnMinutes"] as? Int ?? 0,
                previousOffMinutes: value["previousOffMinutes"] as? Int ?? 0,
                newOnMinutes: value["newOnMinutes"] as? Int ?? 0,
                newOffMinutes: value["newOffMinutes"] as? Int ?? 0,
                note: string(value["note"]),
                hadFloweringPlants: value["hadFloweringPlants"] as? Bool ?? false,
                room: roomByName[string(value["room"])]
            )
            context.insert(event)
            count("LightScheduleEvent")
        }

        // Care reminders
        for value in try arrays("careReminders", in: root) {
            let reminder = CareReminder(
                title: string(value["title"]),
                kind: CareReminderKind(rawValue: string(value["kind"])) ?? .water,
                timeOfDayMinutes: value["timeOfDayMinutes"] as? Int ?? 540,
                repeatDays: value["repeatDays"] as? Int ?? 1,
                isEnabled: value["isEnabled"] as? Bool ?? true,
                lastCompletedAt: date(value["lastCompletedAt"]),
                nextDueDate: date(value["nextDueDate"]) ?? Date(),
                room: roomByName[string(value["room"])]
            )
            context.insert(reminder)
            count("CareReminder")
        }

        // Environment alerts
        for value in try arrays("environmentAlerts", in: root) {
            let low = number(value["targetLow"]) ?? 0
            let high = number(value["targetHigh"]) ?? 0
            let alert = EnvironmentAlert(
                metric: EnvironmentMetric(rawValue: string(value["metric"])) ?? .temperature,
                value: number(value["value"]) ?? 0,
                target: low...max(low, high),
                detectedAt: date(value["detectedAt"]) ?? Date(),
                room: roomByName[string(value["room"])]
            )
            alert.acknowledgedAt = date(value["acknowledgedAt"])
            context.insert(alert)
            count("EnvironmentAlert")
        }

        // Drying and curing
        for value in try arrays("dryingSessions", in: root) {
            let session = DryingSession(
                startedAt: date(value["startedAt"]) ?? Date(),
                phase: DryingPhase(rawValue: string(value["phase"])) ?? .drying,
                profile: DryingProfile(rawValue: string(value["profile"])) ?? .hangDry,
                plant: plantByName[string(value["plant"])]
            )
            session.targetTemperatureLow = number(value["targetTemperatureLow"]) ?? 18
            session.targetTemperatureHigh = number(value["targetTemperatureHigh"]) ?? 21
            session.targetHumidityLow = number(value["targetHumidityLow"]) ?? 58
            session.targetHumidityHigh = number(value["targetHumidityHigh"]) ?? 62
            session.curingStartedAt = date(value["curingStartedAt"])
            session.curingHumidityLow = number(value["curingHumidityLow"]) ?? 58
            session.curingHumidityHigh = number(value["curingHumidityHigh"]) ?? 62
            session.burpMode = BurpMode(rawValue: string(value["burpMode"])) ?? .progressive
            session.lastBurpedAt = date(value["lastBurpedAt"])
            session.endedAt = date(value["endedAt"])
            context.insert(session)
            count("DryingSession")

            for checkValue in value["checks"] as? [[String: Any]] ?? [] {
                let check = DryingCheck(
                    date: date(checkValue["date"]) ?? Date(),
                    humidityPercent: number(checkValue["humidityPercent"]),
                    temperatureC: number(checkValue["temperatureC"]),
                    stemSnap: StemSnap(rawValue: string(checkValue["stemSnap"])),
                    note: string(checkValue["note"]),
                    session: session
                )
                context.insert(check)
                count("DryingCheck")
            }

            for burpValue in value["burps"] as? [[String: Any]] ?? [] {
                let burp = CureBurp(
                    date: date(burpValue["date"]) ?? Date(),
                    note: string(burpValue["note"]),
                    session: session
                )
                context.insert(burp)
                count("CureBurp")
            }
        }

        // Sharing configurations and their access log
        for value in try arrays("shareGrants", in: root) {
            let grant = ShareGrant(
                recipientName: string(value["recipientName"]),
                roomNames: value["rooms"] as? [String] ?? [],
                plantNames: value["plants"] as? [String] ?? [],
                categories: value["categories"] as? [String] ?? [],
                createdAt: date(value["createdAt"]) ?? Date(),
                expiresAt: date(value["expiresAt"]) ?? Date()
            )
            grant.revokedAt = date(value["revokedAt"])
            context.insert(grant)
            count("ShareGrant")

            for logValue in value["accessLogs"] as? [[String: Any]] ?? [] {
                let log = ShareAccessLog(
                    date: date(logValue["date"]) ?? Date(),
                    action: string(logValue["action"]),
                    grant: grant
                )
                context.insert(log)
                count("ShareAccessLog")
            }
        }

        // Compliance history snapshots and their rule change reviews
        for value in try arrays("complianceSnapshots", in: root) {
            let rawStages = value["stageCounts"] as? [String: Any] ?? [:]
            var stages: [PlantStage: Int] = [:]
            for (key, raw) in rawStages {
                guard let stage = PlantStage(rawValue: key),
                      let count = raw as? Int else { continue }
                stages[stage] = count
            }

            let snapshot = ComplianceSnapshot(
                snapshotID: UUID(uuidString: string(value["id"])) ?? UUID(),
                capturedAt: date(value["capturedAt"]) ?? Date(),
                jurisdictionCode: string(value["jurisdictionCode"]),
                stateName: string(value["stateName"]),
                rulePackVersion: string(value["rulePackVersion"]),
                ruleVerifiedOn: string(value["ruleVerifiedOn"]),
                citation: string(value["citation"]),
                sourceURL: string(value["sourceURL"]),
                countedPlantTotal: value["countedPlants"] as? Int ?? 0,
                stageCounts: stages,
                retainedDryWeightGrams: number(value["retainedDryWeightGrams"]) ?? 0,
                canopySquareMeters: number(value["canopySquareMeters"]) ?? 0,
                plantLimit: value["plantLimit"] as? Int,
                possessionLimitGrams: number(value["possessionLimitGrams"]),
                canopyLimitSqM: number(value["canopyLimitSqM"]),
                warningThreshold: number(value["warningThreshold"]) ?? 0.8,
                cultivable: value["cultivable"] as? Bool ?? true,
                countedStages: (value["countedStages"] as? [String] ?? [])
                    .compactMap(PlantStage.init(rawValue:)),
                countsClones: value["countsClones"] as? Bool ?? false,
                limitScope: LimitScope(rawValue: string(value["limitScope"])) ?? .residence,
                plantLevel: ComplianceLevel(rawValue: string(value["plantLevel"])) ?? .unknown,
                possessionLevel: ComplianceLevel(rawValue: string(value["possessionLevel"])) ?? .unknown,
                canopyLevel: ComplianceLevel(rawValue: string(value["canopyLevel"])) ?? .unknown,
                overallLevel: ComplianceLevel(rawValue: string(value["overallLevel"])) ?? .unknown,
                fingerprint: string(value["fingerprint"]),
                isUpgradeBaseline: value["isUpgradeBaseline"] as? Bool ?? false,
                schemaVersion: value["schemaVersion"] as? Int ?? ComplianceSnapshot.currentSchemaVersion
            )
            context.insert(snapshot)
            count("ComplianceSnapshot")
        }

        for value in try arrays("ruleEvaluationEvents", in: root) {
            let changes = (value["changedFields"] as? [[String: Any]] ?? []).map { item in
                RuleFieldChange(
                    field: string(item["field"]),
                    kind: RuleFieldKind(rawValue: string(item["kind"])) ?? .text,
                    previousNumber: number(item["previousNumber"]),
                    newNumber: number(item["newNumber"]),
                    previousText: string(item["previousText"]),
                    newText: string(item["newText"])
                )
            }

            let metrics = (value["metrics"] as? [[String: Any]] ?? []).map { item in
                ComplianceMetricComparison(
                    metric: string(item["metric"]),
                    previousValue: number(item["previousValue"]) ?? 0,
                    previousLimit: number(item["previousLimit"]),
                    previousLevel: string(item["previousLevel"]),
                    currentValue: number(item["currentValue"]) ?? 0,
                    currentLimit: number(item["currentLimit"]),
                    currentLevel: string(item["currentLevel"]),
                    comparable: item["comparable"] as? Bool ?? false
                )
            }

            let event = RuleEvaluationEvent(
                eventID: UUID(uuidString: string(value["id"])) ?? UUID(),
                priorSnapshotID: UUID(uuidString: string(value["priorSnapshotID"])) ?? UUID(),
                priorPackVersion: string(value["priorPackVersion"]),
                newPackVersion: string(value["newPackVersion"]),
                priorRuleVerifiedOn: string(value["priorRuleVerifiedOn"]),
                newRuleVerifiedOn: string(value["newRuleVerifiedOn"]),
                jurisdictionCode: string(value["jurisdictionCode"]),
                evaluatedAt: date(value["evaluatedAt"]) ?? Date(),
                outcome: RuleEvaluationOutcome(rawValue: string(value["outcome"])) ?? .notComparable,
                changedSummary: string(value["changedSummary"]),
                changedFields: changes,
                metrics: metrics,
                citation: string(value["citation"]),
                sourceURL: string(value["sourceURL"]),
                acknowledgedAt: date(value["acknowledgedAt"]),
                schemaVersion: value["schemaVersion"] as? Int ?? RuleEvaluationEvent.currentSchemaVersion
            )
            context.insert(event)
            count("RuleEvaluationEvent")
        }

        // The grower's own cycle goals
        for value in try arrays("goals", in: root) {
            let goal = GrowGoal(
                dryYieldTargetGrams: number(value["dryYieldTargetGrams"]),
                floweringWeeksTarget: value["floweringWeeksTarget"] as? Int,
                loggingCompletenessTargetPercent: value["loggingCompletenessTargetPercent"] as? Int,
                createdAt: date(value["createdAt"]) ?? Date()
            )
            goal.updatedAt = date(value["updatedAt"]) ?? goal.createdAt
            context.insert(goal)
            count("GrowGoal")
        }

        // Journal
        for value in try arrays("journal", in: root) {
            let photoName = string(value["photo"])
            let entry = JournalEntry(
                kind: JournalKind(rawValue: string(value["kind"])) ?? .note,
                text: string(value["text"]),
                tag: ObservationTag(rawValue: string(value["tag"])),
                photoFileName: photoName.isEmpty ? nil : photoName,
                createdAt: date(value["createdAt"]) ?? Date(),
                plant: plantByName[string(value["plant"])],
                room: roomByName[string(value["room"])]
            )
            context.insert(entry)
            count("JournalEntry")
        }

        // Photos last, so a failed write fails before the store is saved.
        if writePhotos {
            for photo in try arrays("photos", in: root) {
                let name = string(photo["fileName"])
                guard !name.isEmpty else { continue }
                guard let data = Data(base64Encoded: string(photo["data"])) else {
                    throw ExportServiceError.invalidBackup("a photo in the backup is not readable")
                }
                try data.write(to: PhotoStore.url(for: name), options: [.atomic, .completeFileProtection])
            }
        }

        try context.save()
        return counts
    }

    // MARK: - Value helpers

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
