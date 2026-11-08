//
//  ComplianceEngine.swift
//  Grow Companion
//
//  Turns plants, rooms and the jurisdiction rule into the numbers shown on the
//  compliance card. Everything is computed on device from local records.
//

import Foundation

enum ComplianceLevel: String, Codable, CaseIterable {
    case good
    case warning
    case over
    case unknown

    var title: String {
        switch self {
        case .good: return "Within limits"
        case .warning: return "Close to a limit"
        case .over: return "Over a limit"
        case .unknown: return "Limit not set"
        }
    }

    var symbolName: String {
        switch self {
        case .good: return "checkmark.seal"
        case .warning: return "exclamationmark.triangle"
        case .over: return "exclamationmark.octagon"
        case .unknown: return "questionmark.circle"
        }
    }

    var rank: Int {
        switch self {
        case .over: return 3
        case .warning: return 2
        case .good: return 1
        case .unknown: return 0
        }
    }
}

struct RoomComplianceBreakdown: Identifiable {
    let id: String
    let roomName: String
    let countedPlants: Int
    let plantNames: [String]
}

struct ComplianceReport {
    let rule: JurisdictionRule
    let countedPlants: Int
    let plantLimit: Int?
    let possessionGrams: Double
    let possessionLimitGrams: Double?
    let canopySqM: Double
    let canopyLimitSqM: Double?
    let warningThreshold: Double

    var plantLevel: ComplianceLevel {
        ComplianceReport.level(value: Double(countedPlants), limit: plantLimit.map(Double.init), threshold: warningThreshold)
    }

    var possessionLevel: ComplianceLevel {
        ComplianceReport.level(value: possessionGrams, limit: possessionLimitGrams, threshold: warningThreshold)
    }

    var canopyLevel: ComplianceLevel {
        ComplianceReport.level(value: canopySqM, limit: canopyLimitSqM, threshold: warningThreshold)
    }

    var overallLevel: ComplianceLevel {
        var result: ComplianceLevel = .good
        for candidate in [plantLevel, possessionLevel, canopyLevel, .unknown] {
            if candidate == .unknown { continue }
            if candidate.rank > result.rank { result = candidate }
        }
        if plantLevel == .unknown && possessionLevel == .unknown && canopyLevel == .unknown {
            return .unknown
        }
        return result
    }

    var progress: Double {
        guard let limit = plantLimit, limit > 0 else { return 0 }
        return min(Double(countedPlants) / Double(limit), 1)
    }

    var statusTitle: String {
        switch overallLevel {
        case .good: return "You're within your limits"
        case .warning: return "You're getting close"
        case .over: return "This is over your limit"
        case .unknown: return "No limit recorded"
        }
    }

    var statusDetail: String {
        switch overallLevel {
        case .good:
            return "Your plant count, stored flower and canopy are inside your jurisdiction's limits."
        case .warning:
            return "One of your metrics is past \(Int((warningThreshold * 100).rounded()))% of the limit. Plan before you add another plant or room."
        case .over:
            return "A metric is at or over a limit. Open the breakdown to see which room and plant are responsible."
        case .unknown:
            return "This jurisdiction's rule pack does not record a numeric limit for the metric you are tracking."
        }
    }

    static func level(value: Double, limit: Double?, threshold: Double) -> ComplianceLevel {
        guard let limit, limit > 0 else { return .unknown }
        let ratio = value / limit
        if ratio > 1.0 { return .over }
        if ratio >= threshold { return .warning }
        return .good
    }
}

enum ComplianceEngine {
    /// Whether a plant counts toward the jurisdiction's plant cap.
    static func counts(_ plant: Plant, rule: JurisdictionRule) -> Bool {
        guard rule.cultivable else { return false }
        guard plant.stage != .storage else { return false }
        guard rule.countedStages.contains(plant.stage) else { return false }
        if plant.stage == .clone && !rule.countsClones { return false }
        if plant.harvestDisposition == .destroyed { return false }
        return true
    }

    static func report(
        plants: [Plant],
        rooms: [Room],
        rule: JurisdictionRule,
        warningThreshold: Double
    ) -> ComplianceReport {
        let counted = plants.filter { counts($0, rule: rule) }

        let possession = plants.reduce(0.0) { $0 + $1.retainedDryWeightGrams }

        let occupiedRoomIDs = Set(counted.compactMap { $0.room?.persistentModelID })
        let canopy = rooms
            .filter { occupiedRoomIDs.contains($0.persistentModelID) }
            .reduce(0.0) { $0 + ($1.canopySquareMeters ?? 0) }

        return ComplianceReport(
            rule: rule,
            countedPlants: counted.count,
            plantLimit: rule.plantLimit,
            possessionGrams: possession,
            possessionLimitGrams: rule.possessionLimitGrams,
            canopySqM: canopy,
            canopyLimitSqM: rule.canopyLimitSqM,
            warningThreshold: warningThreshold
        )
    }

    static func breakdown(plants: [Plant], rooms: [Room], rule: JurisdictionRule) -> [RoomComplianceBreakdown] {
        let counted = plants.filter { counts($0, rule: rule) }
        var rows: [RoomComplianceBreakdown] = []

        for room in rooms {
            let roomPlants = counted.filter { $0.room?.persistentModelID == room.persistentModelID }
            if roomPlants.isEmpty { continue }
            rows.append(
                RoomComplianceBreakdown(
                    id: room.persistentModelID.hashValue.description,
                    roomName: room.name,
                    countedPlants: roomPlants.count,
                    plantNames: roomPlants.map { $0.displayName }
                )
            )
        }

        let assignedIDs = Set(rows.map { $0.id })
        let unassigned = counted.filter { $0.room == nil }
        if !unassigned.isEmpty && assignedIDs.isEmpty {
            rows.append(
                RoomComplianceBreakdown(
                    id: "unassigned",
                    roomName: "No room assigned",
                    countedPlants: unassigned.count,
                    plantNames: unassigned.map { $0.displayName }
                )
            )
        }

        return rows.sorted { $0.roomName < $1.roomName }
    }
}
