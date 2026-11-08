//
//  ComplianceHistoryTests.swift
//  Grow CompanionTests
//
//  Append-only capture, rule change comparison, migration and data-control
//  coverage for the compliance history.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

struct ComplianceHistoryTests {
    // MARK: - Capture

    @Test func snapshotCapturesTheCalculation() throws {
        let context = try makeContext()
        let rule = try californiaRule()
        let room = Room(name: "Tent", canopySquareMeters: 0.5)
        context.insert(room)

        let veg = makePlant(in: context, stage: .veg, room: room)
        let flower = makePlant(in: context, stage: .flower, room: room)
        let stored = makePlant(
            in: context,
            stage: .storage,
            room: room,
            dryGrams: 20,
            disposition: .retained
        )
        try context.save()

        let plants = [veg, flower, stored]
        let report = ComplianceEngine.report(
            plants: plants,
            rooms: [room],
            rule: rule,
            warningThreshold: 0.8
        )

        let snapshot = try #require(
            try ComplianceHistoryService.record(
                report: report,
                plants: plants,
                in: context
            )
        )

        #expect(snapshot.jurisdictionCode == rule.jurisdictionCode)
        #expect(snapshot.stateName == rule.stateName)
        #expect(snapshot.rulePackVersion == RulePack.version)
        #expect(snapshot.countedPlantTotal == report.countedPlants)
        #expect(snapshot.retainedDryWeightGrams == 20)
        #expect(snapshot.canopySquareMeters == 0.5)
        #expect(snapshot.stageCounts[.veg] == 1)
        #expect(snapshot.stageCounts[.flower] == 1)
        #expect(snapshot.stageCounts[.storage] == 0)
        #expect(snapshot.isUpgradeBaseline)
        #expect(!snapshot.citation.isEmpty)
        #expect(!snapshot.fingerprint.isEmpty)
        #expect(snapshot.plantLevel == report.plantLevel)
        #expect(snapshot.overallLevel == report.overallLevel)
    }

    @Test func unchangedCalculationDoesNotAppendASnapshot() throws {
        let context = try makeContext()
        let rule = try californiaRule()
        let plant = makePlant(in: context, stage: .veg)
        try context.save()

        let report = ComplianceEngine.report(
            plants: [plant],
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )

        let first = try #require(
            try ComplianceHistoryService.record(report: report, plants: [plant], in: context)
        )
        let second = try ComplianceHistoryService.record(
            report: report,
            plants: [plant],
            in: context
        )

        #expect(second == nil)
        #expect(first.countedPlantTotal == 1)
        #expect(try context.fetchCount(FetchDescriptor<ComplianceSnapshot>()) == 1)
    }

    @Test func aChangedCalculationAppendsASecondSnapshot() throws {
        let context = try makeContext()
        let rule = try californiaRule()
        let firstPlant = makePlant(in: context, stage: .veg)
        try context.save()

        var plants = [firstPlant]
        var report = ComplianceEngine.report(
            plants: plants,
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )
        _ = try ComplianceHistoryService.record(report: report, plants: plants, in: context)

        let secondPlant = makePlant(in: context, stage: .flower)
        try context.save()
        plants.append(secondPlant)

        report = ComplianceEngine.report(
            plants: plants,
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )
        let second = try #require(
            try ComplianceHistoryService.record(report: report, plants: plants, in: context)
        )

        #expect(!second.isUpgradeBaseline)
        #expect(second.countedPlantTotal == 2)
        #expect(try context.fetchCount(FetchDescriptor<ComplianceSnapshot>()) == 2)
    }

    @Test func anEarlierSnapshotIsNeverRewritten() throws {
        let context = try makeContext()
        let rule = try californiaRule()
        let plant = makePlant(in: context, stage: .flower, dryGrams: 30, disposition: .retained)
        try context.save()

        let report = ComplianceEngine.report(
            plants: [plant],
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )
        let original = try #require(
            try ComplianceHistoryService.record(report: report, plants: [plant], in: context)
        )
        let originalID = original.snapshotID
        let originalWeight = original.retainedDryWeightGrams

        plant.stage = .storage
        plant.harvestDisposition = .destroyed
        try context.save()

        let nextReport = ComplianceEngine.report(
            plants: [plant],
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )
        _ = try ComplianceHistoryService.record(
            report: nextReport,
            plants: [plant],
            in: context
        )

        let stored = try context.fetch(FetchDescriptor<ComplianceSnapshot>())
        let earlier = try #require(stored.first { $0.snapshotID == originalID })
        #expect(earlier.retainedDryWeightGrams == originalWeight)
        #expect(earlier.countedPlantTotal == 1)
        #expect(stored.count == 2)
    }

    // MARK: - Rule change review

    @Test func aRuleChangeIsComparedOnceAndAcknowledged() throws {
        let context = try makeContext()
        let rule = try californiaRule()
        let plant = makePlant(in: context, stage: .flower)
        try context.save()

        let report = ComplianceEngine.report(
            plants: [plant],
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )
        let snapshot = try #require(
            try ComplianceHistoryService.record(
                report: report,
                plants: [plant],
                in: context,
                packVersion: "2025.01.1"
            )
        )

        // Simulate the older pack's tighter plant limit.
        snapshot.plantLimit = 0
        try context.save()

        let events = try ComplianceHistoryService.evaluateRuleChanges(in: context)
        #expect(events.count == 1)

        let event = try #require(events.first)
        #expect(event.priorPackVersion == "2025.01.1")
        #expect(event.newPackVersion == RulePack.version)
        #expect(event.priorSnapshotID == snapshot.snapshotID)
        #expect(event.outcome == .comparable)
        #expect(event.changedFields.contains { $0.field == "plantLimit" })
        #expect(event.changedSummary.contains("Plant limit"))
        #expect(!event.isAcknowledged)
        #expect(event.metrics.count == 3)

        let plantMetric = try #require(event.metrics.first { $0.metric == "plants" })
        #expect(plantMetric.comparable)
        #expect(plantMetric.currentLimit == Double(rule.plantLimit ?? -1))
        #expect(plantMetric.currentValue == 1)
        #expect(plantMetric.currentLevelValue == .over)

        // Re-running the review writes nothing new.
        let repeated = try ComplianceHistoryService.evaluateRuleChanges(in: context)
        #expect(repeated.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<RuleEvaluationEvent>()) == 1)

        try ComplianceHistoryService.acknowledge([event], in: context)
        #expect(event.isAcknowledged)
        #expect(try ComplianceHistoryService.pendingEvents(in: context).isEmpty)
    }

    @Test func anUnsupportedSnapshotFormatIsNotComparable() throws {
        let context = try makeContext()
        let rule = try californiaRule()
        let plant = makePlant(in: context, stage: .veg)
        try context.save()

        let report = ComplianceEngine.report(
            plants: [plant],
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )
        let snapshot = try #require(
            try ComplianceHistoryService.record(
                report: report,
                plants: [plant],
                in: context,
                packVersion: "2025.01.1"
            )
        )
        snapshot.schemaVersion = ComplianceSnapshot.currentSchemaVersion + 1
        try context.save()

        let event = try #require(
            try ComplianceHistoryService.evaluateRuleChanges(in: context).first
        )
        #expect(event.outcome == .notComparable)
        #expect(event.metrics.allSatisfy { !$0.comparable })
        #expect(event.changedFields.isEmpty)
    }

    @Test func aNewerStoredPackIsNotReEvaluated() throws {
        let context = try makeContext()
        let rule = try californiaRule()
        let plant = makePlant(in: context, stage: .veg)
        try context.save()

        let report = ComplianceEngine.report(
            plants: [plant],
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )
        let snapshot = try #require(
            try ComplianceHistoryService.record(
                report: report,
                plants: [plant],
                in: context,
                packVersion: "2099.01.1"
            )
        )

        let event = try #require(
            try ComplianceHistoryService.evaluateRuleChanges(in: context).first
        )
        #expect(event.outcome == .notComparable)
        #expect(event.priorPackVersion == "2099.01.1")
        #expect(snapshot.rulePackVersion == "2099.01.1")
    }

    // MARK: - Schema

    @Test func versionedSchemaKeepsEveryLegacyModel() {
        let legacy = Set(CultivationSchemaV1.models.map { String(describing: $0) })
        let current = Set(CultivationSchemaV2.models.map { String(describing: $0) })

        #expect(current.count == legacy.count + 2)
        #expect(legacy.isSubset(of: current))
        #expect(current.contains("ComplianceSnapshot"))
        #expect(current.contains("RuleEvaluationEvent"))
        #expect(CultivationMigrationPlan.stages.count == 3)
        #expect(DataInventory.modelNames.count == current.count)
    }

    @Test func openingAVersionOneStoreWithTheV2PlanKeepsRecords() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("GrowCompanion.store")

        do {
            let legacy = try ModelContainer(
                for: Schema(versionedSchema: CultivationSchemaV1.self),
                configurations: [
                    ModelConfiguration(
                        "GrowCompanion",
                        schema: Schema(versionedSchema: CultivationSchemaV1.self),
                        url: storeURL
                    )
                ]
            )
            let context = ModelContext(legacy)
            context.insert(Room(name: "Tent"))
            context.insert(Plant(name: "Kept", stage: .veg))
            try context.save()
        }

        let migrated = try ModelContainer(
            for: DataInventory.schema,
            migrationPlan: CultivationMigrationPlan.self,
            configurations: [
                ModelConfiguration("GrowCompanion", schema: DataInventory.schema, url: storeURL)
            ]
        )
        let context = ModelContext(migrated)
        let plants = try context.fetch(FetchDescriptor<Plant>())

        #expect(plants.count == 1)
        #expect(plants.first?.name == "Kept")
        #expect(try context.fetchCount(FetchDescriptor<ComplianceSnapshot>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RuleEvaluationEvent>()) == 0)
    }

    // MARK: - Data controls

    @Test func exportAndBackupCarryComplianceHistory() throws {
        let context = try makeContext()
        let rule = try californiaRule()
        let plant = makePlant(in: context, stage: .veg)
        try context.save()

        let report = ComplianceEngine.report(
            plants: [plant],
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )
        let snapshot = try #require(
            try ComplianceHistoryService.record(
                report: report,
                plants: [plant],
                in: context,
                packVersion: "2025.01.1"
            )
        )
        let event = try #require(
            try ComplianceHistoryService.evaluateRuleChanges(in: context).first
        )

        let counts = DataInventory.counts(in: context)
        #expect(counts["ComplianceSnapshot"] == 1)
        #expect(counts["RuleEvaluationEvent"] == 1)

        let data = try ExportService.jsonData(
            snapshot: ExportSnapshot(
                complianceSnapshots: [snapshot],
                ruleEvaluationEvents: [event],
                counts: counts
            ),
            options: ExportOptions()
        )
        let root = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        let snapshots = root["complianceSnapshots"] as? [[String: Any]]
        let events = root["ruleEvaluationEvents"] as? [[String: Any]]
        #expect(snapshots?.count == 1)
        #expect(events?.count == 1)
        #expect(snapshots?.first?["jurisdictionCode"] as? String == rule.jurisdictionCode)
        #expect(events?.first?["priorPackVersion"] as? String == "2025.01.1")

        let manifest = root["manifest"] as? [String: Any]
        let manifestCounts = manifest?["counts"] as? [String: Any]
        #expect(manifestCounts?["ComplianceSnapshot"] as? Int == 1)
        #expect(manifestCounts?["RuleEvaluationEvent"] as? Int == 1)

        let backup = try ExportService.buildBackup(
            snapshot: ExportSnapshot(
                complianceSnapshots: [snapshot],
                ruleEvaluationEvents: [event],
                counts: counts
            ),
            includeJournal: false,
            includePhotos: false,
            password: "correct-horse-battery"
        )
        let decoded = try ExportService.decodeBackup(backup, password: "correct-horse-battery")
        try BackupService.validate(decoded)
        #expect((decoded["complianceSnapshots"] as? [[String: Any]])?.count == 1)
        #expect((decoded["ruleEvaluationEvents"] as? [[String: Any]])?.count == 1)
    }

    @Test func aBackupWithAMalformedComplianceSectionIsRejected() {
        let document: [String: Any] = [
            "backupVersion": 2,
            "rooms": [],
            "plants": [],
            "complianceSnapshots": "not-a-list"
        ]
        #expect(throws: ExportServiceError.self) {
            try BackupService.validate(document)
        }
    }

    // MARK: - Support

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func californiaRule() throws -> JurisdictionRule {
        try #require(RulePack.rule(forStateCode: "CA"))
    }

    @discardableResult
    private func makePlant(
        in context: ModelContext,
        stage: PlantStage,
        room: Room? = nil,
        dryGrams: Double? = nil,
        disposition: HarvestDisposition? = nil
    ) -> Plant {
        let plant = Plant(name: "Plant", stage: stage, room: room)
        plant.dryWeightGrams = dryGrams
        plant.harvestDisposition = disposition
        context.insert(plant)
        return plant
    }
}
