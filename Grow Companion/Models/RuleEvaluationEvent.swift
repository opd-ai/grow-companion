//
//  RuleEvaluationEvent.swift
//  Grow Companion
//
//  A review of one saved snapshot under a newer rule pack. The snapshot it
//  references is never changed: the comparison itself is appended here.
//

import Foundation
import SwiftData

enum RuleEvaluationOutcome: String, Codable, CaseIterable {
    case comparable
    case notComparable
}

/// How one changed rule field is shown. `count`, `grams` and `squareMeters`
/// keep their numbers so the review can follow the grower's unit setting.
enum RuleFieldKind: String, Codable, Hashable {
    case count
    case grams
    case squareMeters
    case stages
    case yesNo
    case text
}

struct RuleFieldChange: Codable, Hashable, Identifiable {
    let field: String
    let kind: RuleFieldKind
    let previousNumber: Double?
    let newNumber: Double?
    let previousText: String
    let newText: String

    var id: String { field }

    var label: String {
        switch field {
        case "plantLimit": return "Plant limit"
        case "limitScope": return "Plant limit scope"
        case "cultivable": return "Home cultivation"
        case "countedStages": return "Counted stages"
        case "countsClones": return "Clones count"
        case "possessionLimit": return "Stored flower limit"
        case "canopyLimit": return "Canopy limit"
        default: return field
        }
    }

    func display(previous: Bool, unit: UnitSystem) -> String {
        let number = previous ? previousNumber : newNumber
        let text = previous ? previousText : newText

        switch kind {
        case .count:
            guard let number else { return "Not recorded" }
            return "\(Int(number.rounded()))"
        case .grams:
            guard let number else { return "Not recorded" }
            return Format.weight(number, unit: unit)
        case .squareMeters:
            guard let number else { return "Not recorded" }
            return Format.area(number, unit: unit)
        case .stages:
            return text.isEmpty ? "None" : text
        case .yesNo:
            guard let number else { return text.isEmpty ? "Not recorded" : text }
            return number > 0 ? "Yes" : "No"
        case .text:
            return text
        }
    }
}

struct ComplianceMetricComparison: Codable, Hashable, Identifiable {
    let metric: String
    let previousValue: Double
    let previousLimit: Double?
    let previousLevel: String
    let currentValue: Double
    let currentLimit: Double?
    let currentLevel: String
    let comparable: Bool

    var id: String { metric }

    var label: String {
        switch metric {
        case "plants": return "Counted plants"
        case "possession": return "Stored flower"
        case "canopy": return "Canopy"
        default: return metric
        }
    }

    var previousLevelValue: ComplianceLevel {
        ComplianceLevel(rawValue: previousLevel) ?? .unknown
    }

    var currentLevelValue: ComplianceLevel {
        ComplianceLevel(rawValue: currentLevel) ?? .unknown
    }

    func valueText(previous: Bool, unit: UnitSystem) -> String {
        let value = previous ? previousValue : currentValue
        let limit = previous ? previousLimit : currentLimit

        switch metric {
        case "plants":
            let count = "\(Int(value.rounded()))"
            guard let limit else { return count }
            return "\(count) / \(Int(limit.rounded()))"
        case "possession":
            return "\(Format.weight(value, unit: unit)) / \(Format.weightLimit(limit, unit: unit))"
        case "canopy":
            guard let limit else { return Format.area(value, unit: unit) }
            return "\(Format.area(value, unit: unit)) / \(Format.area(limit, unit: unit))"
        default:
            return "\(value)"
        }
    }
}

@Model
final class RuleEvaluationEvent {
    @Attribute(.unique) var eventID: UUID = UUID()

    var priorSnapshotID: UUID = UUID()
    var priorPackVersion: String = ""
    var newPackVersion: String = ""
    var priorRuleVerifiedOn: String = ""
    var newRuleVerifiedOn: String = ""
    var jurisdictionCode: String = ""

    var evaluatedAt: Date = Date()
    var outcomeRaw: String = RuleEvaluationOutcome.comparable.rawValue
    var changedSummary: String = ""

    var changedFieldsData: Data = Data()
    var metricComparisonsData: Data = Data()

    var citation: String = ""
    var sourceURL: String = ""

    var acknowledgedAt: Date?
    var schemaVersion: Int = RuleEvaluationEvent.currentSchemaVersion

    static let currentSchemaVersion = 1

    init(
        eventID: UUID = UUID(),
        priorSnapshotID: UUID,
        priorPackVersion: String,
        newPackVersion: String,
        priorRuleVerifiedOn: String = "",
        newRuleVerifiedOn: String = "",
        jurisdictionCode: String,
        evaluatedAt: Date = Date(),
        outcome: RuleEvaluationOutcome,
        changedSummary: String,
        changedFields: [RuleFieldChange] = [],
        metrics: [ComplianceMetricComparison] = [],
        citation: String = "",
        sourceURL: String = "",
        acknowledgedAt: Date? = nil,
        schemaVersion: Int = RuleEvaluationEvent.currentSchemaVersion
    ) {
        self.eventID = eventID
        self.priorSnapshotID = priorSnapshotID
        self.priorPackVersion = priorPackVersion
        self.newPackVersion = newPackVersion
        self.priorRuleVerifiedOn = priorRuleVerifiedOn
        self.newRuleVerifiedOn = newRuleVerifiedOn
        self.jurisdictionCode = jurisdictionCode
        self.evaluatedAt = evaluatedAt
        self.outcomeRaw = outcome.rawValue
        self.changedSummary = changedSummary
        self.changedFieldsData = CompliancePayloadCoding.encode(changedFields)
        self.metricComparisonsData = CompliancePayloadCoding.encode(metrics)
        self.citation = citation
        self.sourceURL = sourceURL
        self.acknowledgedAt = acknowledgedAt
        self.schemaVersion = schemaVersion
    }

    var outcome: RuleEvaluationOutcome {
        RuleEvaluationOutcome(rawValue: outcomeRaw) ?? .notComparable
    }

    var changedFields: [RuleFieldChange] {
        CompliancePayloadCoding.decode([RuleFieldChange].self, from: changedFieldsData) ?? []
    }

    var metrics: [ComplianceMetricComparison] {
        CompliancePayloadCoding.decode(
            [ComplianceMetricComparison].self,
            from: metricComparisonsData
        ) ?? []
    }

    var isAcknowledged: Bool { acknowledgedAt != nil }
}

enum CompliancePayloadCoding {
    static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
