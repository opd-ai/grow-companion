//
//  ComplianceHistory.swift
//  Grow Companion
//
//  Captures an append-only snapshot of the compliance calculation, re-checks
//  saved snapshots when the bundled rule pack changes, and records the
//  grower's acknowledgment of that review. Everything is on device; the
//  snapshots store only inputs the evaluator uses and never a plant or room
//  name.
//

import CryptoKit
import Foundation
import Observation
import SwiftData
import os

enum ComplianceHistoryService {
    // MARK: - Capture

    /// Writes a snapshot when the current calculation differs from the last
    /// one. Returns nil when nothing changed, so repeated views or launches do
    /// not append duplicate records.
    @discardableResult
    static func record(
        report: ComplianceReport,
        plants: [Plant],
        in context: ModelContext,
        now: Date = Date(),
        packVersion: String = RulePack.version
    ) throws -> ComplianceSnapshot? {
        let stageCounts = stageBuckets(for: plants)
        let fingerprint = fingerprint(
            report: report,
            stageCounts: stageCounts,
            packVersion: packVersion
        )
        let latest = try latestSnapshot(in: context)

        if let latest,
           latest.fingerprint == fingerprint,
           latest.rulePackVersion == packVersion,
           latest.jurisdictionCode == report.rule.jurisdictionCode {
            return nil
        }

        let snapshot = ComplianceSnapshot(
            capturedAt: now,
            jurisdictionCode: report.rule.jurisdictionCode,
            stateName: report.rule.stateName,
            rulePackVersion: packVersion,
            ruleVerifiedOn: report.rule.verifiedOn,
            citation: report.rule.citation,
            sourceURL: report.rule.sourceURL,
            countedPlantTotal: report.countedPlants,
            stageCounts: stageCounts,
            retainedDryWeightGrams: report.possessionGrams,
            canopySquareMeters: report.canopySqM,
            plantLimit: report.plantLimit,
            possessionLimitGrams: report.possessionLimitGrams,
            canopyLimitSqM: report.canopyLimitSqM,
            warningThreshold: report.warningThreshold,
            cultivable: report.rule.cultivable,
            countedStages: report.rule.countedStages,
            countsClones: report.rule.countsClones,
            limitScope: report.rule.limitScope,
            plantLevel: report.plantLevel,
            possessionLevel: report.possessionLevel,
            canopyLevel: report.canopyLevel,
            overallLevel: report.overallLevel,
            fingerprint: fingerprint,
            isUpgradeBaseline: latest == nil
        )

        context.insert(snapshot)
        try context.save()
        return snapshot
    }

    /// Every stage with a count, zero buckets included. The storage stage and
    /// destroyed plants are excluded exactly as `ComplianceEngine.counts` does,
    /// and nothing is filtered by the current rule so a later rule pack can be
    /// compared against the same buckets.
    static func stageBuckets(for plants: [Plant]) -> [PlantStage: Int] {
        var counts = Dictionary(
            uniqueKeysWithValues: PlantStage.allCases.map { ($0, 0) }
        )

        for plant in plants where plant.harvestDisposition != .destroyed && plant.stage != .storage {
            counts[plant.stage, default: 0] += 1
        }

        return counts
    }

    /// A stable description of everything the displayed calculation depends
    /// on, so an unchanged garden does not write a duplicate snapshot.
    static func fingerprint(
        report: ComplianceReport,
        stageCounts: [PlantStage: Int],
        packVersion: String
    ) -> String {
        let stagePart = PlantStage.allCases
            .map { "\($0.rawValue)=\(stageCounts[$0] ?? 0)" }
            .joined(separator: ",")

        let parts = [
            "schema=\(ComplianceSnapshot.currentSchemaVersion)",
            "jurisdiction=\(report.rule.jurisdictionCode)",
            "pack=\(packVersion)",
            "warning=\(decimal(report.warningThreshold, digits: 4))",
            "cultivable=\(report.rule.cultivable)",
            "plantLimit=\(report.plantLimit.map(String.init) ?? "-")",
            "possessionLimit=\(decimal(report.possessionLimitGrams, digits: 3))",
            "canopyLimit=\(decimal(report.canopyLimitSqM, digits: 4))",
            "counted=\(report.countedPlants)",
            "possession=\(decimal(report.possessionGrams, digits: 3))",
            "canopy=\(decimal(report.canopySqM, digits: 4))",
            "stages=\(stagePart)",
            "countedStages=\(report.rule.countedStages.map(\.rawValue).joined(separator: ","))",
            "countsClones=\(report.rule.countsClones)",
            "scope=\(report.rule.limitScope.rawValue)"
        ]

        let digest = SHA256.hash(data: Data(parts.joined(separator: "|").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Reading

    static func latestSnapshot(in context: ModelContext) throws -> ComplianceSnapshot? {
        var descriptor = FetchDescriptor<ComplianceSnapshot>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    static func pendingEvents(in context: ModelContext) throws -> [RuleEvaluationEvent] {
        let events = try context.fetch(
            FetchDescriptor<RuleEvaluationEvent>(
                sortBy: [SortDescriptor(\.evaluatedAt, order: .reverse)]
            )
        )
        return events.filter { $0.acknowledgedAt == nil }
    }

    // MARK: - Rule change review

    /// Compares every saved snapshot that was recorded under a different pack
    /// against the current one, appending one event per snapshot. Re-running it
    /// writes nothing new: the event identifier is derived from the snapshot and
    /// the new pack version.
    @discardableResult
    static func evaluateRuleChanges(
        in context: ModelContext,
        now: Date = Date(),
        packVersion: String = RulePack.version,
        verifiedOn: String = RulePack.verifiedOn
    ) throws -> [RuleEvaluationEvent] {
        let snapshots = try context.fetch(
            FetchDescriptor<ComplianceSnapshot>(
                sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
            )
        )
        let existing = try context.fetch(FetchDescriptor<RuleEvaluationEvent>())
        var knownIDs = Set(existing.map(\.eventID))
        var created: [RuleEvaluationEvent] = []

        for snapshot in snapshots where snapshot.rulePackVersion != packVersion {
            let eventID = eventID(
                priorSnapshotID: snapshot.snapshotID,
                newPackVersion: packVersion
            )
            guard !knownIDs.contains(eventID) else { continue }

            let rule = RulePack.rule(forStateCode: stateCode(from: snapshot.jurisdictionCode))
            let comparison: RuleComparison
            if snapshot.schemaVersion > ComplianceSnapshot.currentSchemaVersion {
                comparison = notComparableComparison(
                    snapshot: snapshot,
                    summary: "This record was saved in a newer snapshot format and cannot be compared here."
                )
            } else if versionOrder(snapshot.rulePackVersion, packVersion) == .orderedDescending {
                comparison = notComparableComparison(
                    snapshot: snapshot,
                    summary: "This record came from a newer rule pack than this build carries. It stays as recorded and is not re-evaluated."
                )
            } else if let rule {
                comparison = compare(snapshot: snapshot, rule: rule)
            } else {
                comparison = notComparableComparison(
                    snapshot: snapshot,
                    summary: "This record's jurisdiction is not in the current rule pack, so it cannot be compared."
                )
            }

            let event = RuleEvaluationEvent(
                eventID: eventID,
                priorSnapshotID: snapshot.snapshotID,
                priorPackVersion: snapshot.rulePackVersion,
                newPackVersion: packVersion,
                priorRuleVerifiedOn: snapshot.ruleVerifiedOn,
                newRuleVerifiedOn: verifiedOn,
                jurisdictionCode: snapshot.jurisdictionCode,
                evaluatedAt: now,
                outcome: comparison.outcome,
                changedSummary: comparison.changedSummary,
                changedFields: comparison.changedFields,
                metrics: comparison.metrics,
                citation: rule?.citation ?? "",
                sourceURL: rule?.sourceURL ?? ""
            )

            context.insert(event)
            created.append(event)
            knownIDs.insert(eventID)
        }

        if !created.isEmpty {
            try context.save()
        }
        return created
    }

    static func acknowledge(
        _ events: [RuleEvaluationEvent],
        in context: ModelContext,
        now: Date = Date()
    ) throws {
        var changed = false
        for event in events where event.acknowledgedAt == nil {
            event.acknowledgedAt = now
            changed = true
        }
        if changed {
            try context.save()
        }
    }

    // MARK: - Comparison

    private struct RuleComparison {
        let outcome: RuleEvaluationOutcome
        let metrics: [ComplianceMetricComparison]
        let changedFields: [RuleFieldChange]
        let changedSummary: String
    }

    private static func compare(
        snapshot: ComplianceSnapshot,
        rule: RuleConfiguration
    ) -> RuleComparison {
        let stages = snapshot.stageCounts
        let countedStagesKnown = rule.countedStages.allSatisfy { stages[$0] != nil }

        let countedPlants = rule.count(countedStages: rule.countedStages, in: stages)
        let plantLevel = countedPlants.flatMap { count in
            rule.level(
                for: Double(count),
                limit: rule.plantLimit.map(Double.init),
                threshold: snapshot.warningThreshold
            )
        } ?? snapshot.plantLevel

        let possessionLevel = rule.level(
            for: snapshot.retainedDryWeightGrams,
            limit: rule.possessionLimitGrams,
            threshold: snapshot.warningThreshold
        ) ?? snapshot.possessionLevel

        // The stored canopy total came from the set of rooms occupied by the
        // plants the old rule counted. It can only be compared when that set
        // is unchanged; otherwise the total would be re-used out of context.
        let sameOccupancy = Set(rule.countedStages) == Set(snapshot.countedStages)
            && rule.countsClones == snapshot.countsClones
            && rule.cultivable == snapshot.cultivable
        let canopyLevel = sameOccupancy
            ? rule.level(
                for: snapshot.canopySquareMeters,
                limit: rule.canopyLimitSqM,
                threshold: snapshot.warningThreshold
            ) ?? snapshot.canopyLevel
            : snapshot.canopyLevel

        let plantsComparable = countedStagesKnown
        let possessionComparable = true
        let canopyComparable = sameOccupancy

        let overallLevel: ComplianceLevel
        if plantsComparable && possessionComparable && canopyComparable {
            overallLevel = overall(
                plant: plantLevel,
                possession: possessionLevel,
                canopy: canopyLevel
            )
        } else {
            overallLevel = snapshot.overallLevel
        }

        let metrics = [
            metric(
                name: "plants",
                previousValue: Double(snapshot.countedPlantTotal),
                previousLimit: snapshot.plantLimit.map(Double.init),
                previousLevel: snapshot.plantLevel,
                currentValue: Double(countedPlants ?? snapshot.countedPlantTotal),
                currentLimit: rule.plantLimit.map(Double.init),
                currentLevel: plantLevel,
                comparable: plantsComparable
            ),
            metric(
                name: "possession",
                previousValue: snapshot.retainedDryWeightGrams,
                previousLimit: snapshot.possessionLimitGrams,
                previousLevel: snapshot.possessionLevel,
                currentValue: snapshot.retainedDryWeightGrams,
                currentLimit: rule.possessionLimitGrams,
                currentLevel: possessionLevel,
                comparable: possessionComparable
            ),
            metric(
                name: "canopy",
                previousValue: snapshot.canopySquareMeters,
                previousLimit: snapshot.canopyLimitSqM,
                previousLevel: snapshot.canopyLevel,
                currentValue: snapshot.canopySquareMeters,
                currentLimit: rule.canopyLimitSqM,
                currentLevel: canopyLevel,
                comparable: canopyComparable
            )
        ]

        let outcome: RuleEvaluationOutcome = metrics.allSatisfy(\.comparable)
            ? .comparable
            : .notComparable
        let fields = fieldChanges(snapshot: snapshot, rule: rule)

        return RuleComparison(
            outcome: outcome,
            metrics: metrics,
            changedFields: fields,
            changedSummary: summary(
                fields: fields,
                metrics: metrics,
                outcome: outcome,
                overall: overallLevel
            )
        )
    }

    private static func notComparableComparison(
        snapshot: ComplianceSnapshot,
        summary: String
    ) -> RuleComparison {
        let metrics = [
            metric(
                name: "plants",
                previousValue: Double(snapshot.countedPlantTotal),
                previousLimit: snapshot.plantLimit.map(Double.init),
                previousLevel: snapshot.plantLevel,
                currentValue: Double(snapshot.countedPlantTotal),
                currentLimit: snapshot.plantLimit.map(Double.init),
                currentLevel: snapshot.plantLevel,
                comparable: false
            ),
            metric(
                name: "possession",
                previousValue: snapshot.retainedDryWeightGrams,
                previousLimit: snapshot.possessionLimitGrams,
                previousLevel: snapshot.possessionLevel,
                currentValue: snapshot.retainedDryWeightGrams,
                currentLimit: snapshot.possessionLimitGrams,
                currentLevel: snapshot.possessionLevel,
                comparable: false
            ),
            metric(
                name: "canopy",
                previousValue: snapshot.canopySquareMeters,
                previousLimit: snapshot.canopyLimitSqM,
                previousLevel: snapshot.canopyLevel,
                currentValue: snapshot.canopySquareMeters,
                currentLimit: snapshot.canopyLimitSqM,
                currentLevel: snapshot.canopyLevel,
                comparable: false
            )
        ]

        return RuleComparison(
            outcome: .notComparable,
            metrics: metrics,
            changedFields: [],
            changedSummary: summary
        )
    }

    private static func fieldChanges(
        snapshot: ComplianceSnapshot,
        rule: RuleConfiguration
    ) -> [RuleFieldChange] {
        var changes: [RuleFieldChange] = []

        func add(_ change: RuleFieldChange) {
            guard !changes.contains(where: { $0.field == change.field }) else { return }
            changes.append(change)
        }

        func addNumber(
            field: String,
            kind: RuleFieldKind,
            previous: Double?,
            new: Double?,
            previousText: String = "",
            newText: String = ""
        ) {
            guard previous != new else { return }
            add(
                RuleFieldChange(
                    field: field,
                    kind: kind,
                    previousNumber: previous,
                    newNumber: new,
                    previousText: previousText,
                    newText: newText
                )
            )
        }

        addNumber(
            field: "plantLimit",
            kind: .count,
            previous: snapshot.plantLimit.map(Double.init),
            new: rule.plantLimit.map(Double.init)
        )

        if snapshot.limitScope != rule.limitScope {
            add(
                RuleFieldChange(
                    field: "limitScope",
                    kind: .text,
                    previousNumber: nil,
                    newNumber: nil,
                    previousText: snapshot.limitScope.title,
                    newText: rule.limitScope.title
                )
            )
        }

        if snapshot.cultivable != rule.cultivable {
            add(
                RuleFieldChange(
                    field: "cultivable",
                    kind: .yesNo,
                    previousNumber: snapshot.cultivable ? 1 : 0,
                    newNumber: rule.cultivable ? 1 : 0,
                    previousText: "",
                    newText: ""
                )
            )
            return changes
        }

        if Set(snapshot.countedStages) != Set(rule.countedStages) {
            add(
                RuleFieldChange(
                    field: "countedStages",
                    kind: .stages,
                    previousNumber: nil,
                    newNumber: nil,
                    previousText: snapshot.countedStages.map(\.title).joined(separator: ", "),
                    newText: rule.countedStages.map(\.title).joined(separator: ", ")
                )
            )
        }

        if snapshot.countsClones != rule.countsClones {
            add(
                RuleFieldChange(
                    field: "countsClones",
                    kind: .yesNo,
                    previousNumber: snapshot.countsClones ? 1 : 0,
                    newNumber: rule.countsClones ? 1 : 0,
                    previousText: "",
                    newText: ""
                )
            )
        }

        addNumber(
            field: "possessionLimit",
            kind: .grams,
            previous: snapshot.possessionLimitGrams,
            new: rule.possessionLimitGrams
        )

        addNumber(
            field: "canopyLimit",
            kind: .squareMeters,
            previous: snapshot.canopyLimitSqM,
            new: rule.canopyLimitSqM
        )

        return changes
    }

    private static func metric(
        name: String,
        previousValue: Double,
        previousLimit: Double?,
        previousLevel: ComplianceLevel,
        currentValue: Double,
        currentLimit: Double?,
        currentLevel: ComplianceLevel,
        comparable: Bool
    ) -> ComplianceMetricComparison {
        ComplianceMetricComparison(
            metric: name,
            previousValue: previousValue,
            previousLimit: previousLimit,
            previousLevel: previousLevel.rawValue,
            currentValue: currentValue,
            currentLimit: currentLimit,
            currentLevel: currentLevel.rawValue,
            comparable: comparable
        )
    }

    private static func summary(
        fields: [RuleFieldChange],
        metrics: [ComplianceMetricComparison],
        outcome: RuleEvaluationOutcome,
        overall: ComplianceLevel
    ) -> String {
        var pieces: [String] = []

        if fields.isEmpty {
            pieces.append("No limit changed for this record.")
        } else {
            let names = fields.prefix(4).map(\.label).joined(separator: ", ")
            pieces.append("Changed: \(names).")
        }

        let changedResults = metrics.filter {
            $0.comparable && $0.previousLevel != $0.currentLevel
        }
        if !changedResults.isEmpty {
            let names = changedResults.map(\.label).joined(separator: ", ")
            pieces.append("The result changes for \(names), now \(overall.title.lowercased()).")
        } else if outcome == .comparable {
            pieces.append("The result stays the same.")
        }

        if outcome == .notComparable {
            pieces.append("This record cannot be compared with the inputs it stored.")
        }

        return pieces.joined(separator: " ")
    }

    private static func overall(
        plant: ComplianceLevel,
        possession: ComplianceLevel,
        canopy: ComplianceLevel
    ) -> ComplianceLevel {
        let levels = [plant, possession, canopy].filter { $0 != .unknown }
        guard !levels.isEmpty else { return .unknown }
        return levels.max { $0.rank < $1.rank } ?? .unknown
    }

    // MARK: - Identifiers and versions

    /// Derived from the snapshot and the new pack version, so the same review
    /// is never appended twice, even across launches.
    private static func eventID(priorSnapshotID: UUID, newPackVersion: String) -> UUID {
        let digest = SHA256.hash(
            data: Data("\(priorSnapshotID.uuidString)|\(newPackVersion)".utf8)
        )
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let parts = [
            String(hex.prefix(8)),
            String(hex.dropFirst(8).prefix(4)),
            String(hex.dropFirst(12).prefix(4)),
            String(hex.dropFirst(16).prefix(4)),
            String(hex.dropFirst(20).prefix(12))
        ]
        return UUID(uuidString: parts.joined(separator: "-")) ?? UUID()
    }

    private static func stateCode(from jurisdictionCode: String) -> String {
        jurisdictionCode.split(separator: "-").last.map(String.init) ?? jurisdictionCode
    }

    /// Numeric comparison of dotted pack versions such as 2025.05.1.
    private static func versionOrder(_ left: String, _ right: String) -> ComparisonResult {
        let leftParts = left.split(separator: ".").map { Int($0) ?? 0 }
        let rightParts = right.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(leftParts.count, rightParts.count)

        for index in 0..<count {
            let leftValue = index < leftParts.count ? leftParts[index] : 0
            let rightValue = index < rightParts.count ? rightParts[index] : 0
            if leftValue != rightValue {
                return leftValue < rightValue ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }

    private static func decimal(_ value: Double?, digits: Int) -> String {
        guard let value else { return "-" }
        return String(
            format: "%.\(digits)f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}

// MARK: - Monitor

/// Keeps the saved history in step with the live garden. Injected at the tab
/// root so Home and Rules report the same state, and so a write failure is
/// visible on the compliance surfaces instead of being swallowed.
@MainActor
@Observable
final class ComplianceHistoryMonitor {
    private(set) var lastError: String?
    private(set) var lastSavedAt: Date?
    private(set) var pendingChangeCount = 0

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GrowCompanion",
        category: "ComplianceHistory"
    )

    func sync(
        profile: GrowProfile?,
        plants: [Plant],
        rooms: [Room],
        warningThreshold: Double,
        in context: ModelContext
    ) {
        guard let profile, let rule = profile.rule else {
            pendingChangeCount = 0
            return
        }

        do {
            let report = ComplianceEngine.report(
                plants: plants,
                rooms: rooms,
                rule: rule,
                warningThreshold: warningThreshold
            )
            let previous = try ComplianceHistoryService.latestSnapshot(in: context)
            let recorded = try ComplianceHistoryService.record(report: report, plants: plants, in: context)
            if let recorded {
                // Story 2: a move towards a limit is the one status change the
                // grower is told about outside the app.
                ComplianceStatusNotifier.notifyIfNeeded(previous: previous, current: recorded)
            }
            _ = try ComplianceHistoryService.evaluateRuleChanges(in: context)
            lastSavedAt = try ComplianceHistoryService.latestSnapshot(in: context)?.capturedAt
            pendingChangeCount = try ComplianceHistoryService.pendingEvents(in: context).count
            lastError = nil
        } catch {
            lastError = "History could not be saved."
            logger.error(
                "Compliance history write failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

// MARK: - Rule content

/// The rule fields a comparison reads. A small protocol keeps the comparison
/// independent of the bundled pack type and testable with a fixture.
protocol RuleConfiguration {
    var stateCode: String { get }
    var stateName: String { get }
    var cultivable: Bool { get }
    var plantLimit: Int? { get }
    var limitScope: LimitScope { get }
    var countedStages: [PlantStage] { get }
    var countsClones: Bool { get }
    var possessionLimitGrams: Double? { get }
    var canopyLimitSqM: Double? { get }
    var citation: String { get }
    var sourceURL: String { get }
    var verifiedOn: String { get }
}

extension JurisdictionRule: RuleConfiguration {}

private extension RuleConfiguration {
    func count(countedStages: [PlantStage], in stages: [PlantStage: Int]) -> Int? {
        guard allStagesStored(countedStages, in: stages) else { return nil }
        guard cultivable else { return 0 }
        return countedStages.reduce(0) { total, stage in
            if stage == .clone && !countsClones { return total }
            return total + (stages[stage] ?? 0)
        }
    }

    func allStagesStored(_ stagesNeeded: [PlantStage], in stages: [PlantStage: Int]) -> Bool {
        stagesNeeded.allSatisfy { stages[$0] != nil }
    }

    func level(for value: Double, limit: Double?, threshold: Double) -> ComplianceLevel? {
        ComplianceReport.level(value: value, limit: limit, threshold: threshold)
    }
}
