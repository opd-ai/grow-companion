//
//  ComplianceSnapshot.swift
//  Grow Companion
//
//  One append-only record of a compliance calculation the app displayed:
//  the inputs the engine used, the rule pack behind them, and the result.
//  A snapshot is never rewritten; a later calculation is a new record.
//

import Foundation
import SwiftData

@Model
final class ComplianceSnapshot {
    /// Stable identifier, referenced by a rule review event.
    @Attribute(.unique) var snapshotID: UUID = UUID()

    var capturedAt: Date = Date()

    var jurisdictionCode: String = ""
    var stateName: String = ""
    var rulePackVersion: String = ""
    var ruleVerifiedOn: String = ""
    var citation: String = ""
    var sourceURL: String = ""

    var countedPlantTotal: Int = 0

    /// Every plant stage with its count, zero buckets included, so a later
    /// rule pack can be compared without guessing a stage that was not stored.
    var stageCountsData: Data = Data()

    var retainedDryWeightGrams: Double = 0
    var canopySquareMeters: Double = 0

    var plantLimit: Int?
    var possessionLimitGrams: Double?
    var canopyLimitSqM: Double?

    var warningThreshold: Double = 0.8

    var cultivable: Bool = true
    var countedStagesRaw: String = ""
    var countsClones: Bool = false
    var limitScopeRaw: String = LimitScope.residence.rawValue

    var plantLevelRaw: String = ComplianceLevel.unknown.rawValue
    var possessionLevelRaw: String = ComplianceLevel.unknown.rawValue
    var canopyLevelRaw: String = ComplianceLevel.unknown.rawValue
    var overallLevelRaw: String = ComplianceLevel.unknown.rawValue

    var fingerprint: String = ""

    var isUpgradeBaseline: Bool = false
    var schemaVersion: Int = ComplianceSnapshot.currentSchemaVersion

    static let currentSchemaVersion = 1

    init(
        snapshotID: UUID = UUID(),
        capturedAt: Date = Date(),
        jurisdictionCode: String = "",
        stateName: String = "",
        rulePackVersion: String = "",
        ruleVerifiedOn: String = "",
        citation: String = "",
        sourceURL: String = "",
        countedPlantTotal: Int = 0,
        stageCounts: [PlantStage: Int] = [:],
        retainedDryWeightGrams: Double = 0,
        canopySquareMeters: Double = 0,
        plantLimit: Int? = nil,
        possessionLimitGrams: Double? = nil,
        canopyLimitSqM: Double? = nil,
        warningThreshold: Double = 0.8,
        cultivable: Bool = true,
        countedStages: [PlantStage] = [],
        countsClones: Bool = false,
        limitScope: LimitScope = .residence,
        plantLevel: ComplianceLevel = .unknown,
        possessionLevel: ComplianceLevel = .unknown,
        canopyLevel: ComplianceLevel = .unknown,
        overallLevel: ComplianceLevel = .unknown,
        fingerprint: String = "",
        isUpgradeBaseline: Bool = false,
        schemaVersion: Int = ComplianceSnapshot.currentSchemaVersion
    ) {
        self.snapshotID = snapshotID
        self.capturedAt = capturedAt
        self.jurisdictionCode = jurisdictionCode
        self.stateName = stateName
        self.rulePackVersion = rulePackVersion
        self.ruleVerifiedOn = ruleVerifiedOn
        self.citation = citation
        self.sourceURL = sourceURL
        self.countedPlantTotal = countedPlantTotal
        self.stageCountsData = CompliancePayloadCoding.encode(stageCounts.mapKeys(\.rawValue))
        self.retainedDryWeightGrams = retainedDryWeightGrams
        self.canopySquareMeters = canopySquareMeters
        self.plantLimit = plantLimit
        self.possessionLimitGrams = possessionLimitGrams
        self.canopyLimitSqM = canopyLimitSqM
        self.warningThreshold = warningThreshold
        self.cultivable = cultivable
        self.countedStagesRaw = countedStages.map(\.rawValue).joined(separator: ",")
        self.countsClones = countsClones
        self.limitScopeRaw = limitScope.rawValue
        self.plantLevelRaw = plantLevel.rawValue
        self.possessionLevelRaw = possessionLevel.rawValue
        self.canopyLevelRaw = canopyLevel.rawValue
        self.overallLevelRaw = overallLevel.rawValue
        self.fingerprint = fingerprint
        self.isUpgradeBaseline = isUpgradeBaseline
        self.schemaVersion = schemaVersion
    }

    // MARK: Decoded values

    var stageCounts: [PlantStage: Int] {
        guard let raw = CompliancePayloadCoding.decode(
            [String: Int].self,
            from: stageCountsData
        ) else { return [:] }

        var result: [PlantStage: Int] = [:]
        for (key, value) in raw {
            guard let stage = PlantStage(rawValue: key) else { continue }
            result[stage] = value
        }
        return result
    }

    var countedStages: [PlantStage] {
        countedStagesRaw
            .split(separator: ",")
            .compactMap { PlantStage(rawValue: String($0)) }
    }

    var limitScope: LimitScope {
        LimitScope(rawValue: limitScopeRaw) ?? .residence
    }

    var plantLevel: ComplianceLevel { ComplianceLevel(rawValue: plantLevelRaw) ?? .unknown }
    var possessionLevel: ComplianceLevel { ComplianceLevel(rawValue: possessionLevelRaw) ?? .unknown }
    var canopyLevel: ComplianceLevel { ComplianceLevel(rawValue: canopyLevelRaw) ?? .unknown }
    var overallLevel: ComplianceLevel { ComplianceLevel(rawValue: overallLevelRaw) ?? .unknown }

    /// The plants this snapshot itself counted, by the stages the rule used.
    var countedStageTotal: Int {
        countedStages.reduce(0) { total, stage in
            if stage == .clone && !countsClones { return total }
            return total + (stageCounts[stage] ?? 0)
        }
    }
}

private extension Dictionary where Key == PlantStage, Value == Int {
    func mapKeys(_ transform: (Key) -> String) -> [String: Int] {
        var result: [String: Int] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
