//
//  GrowGoals.swift
//  Grow Companion
//
//  The grower's own cycle targets, measured against the records that exist.
//  A figure the app has nothing to measure is reported as missing, never as
//  zero, and nothing here grades the grow or compares it with another grower.
//

import Foundation
import SwiftData

enum GrowGoalKind: String, CaseIterable, Identifiable {
    case dryYield
    case floweringWeeks
    case loggingCompleteness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dryYield: return "Dry yield"
        case .floweringWeeks: return "Flowering time"
        case .loggingCompleteness: return "Logging completeness"
        }
    }

    var subtitle: String {
        switch self {
        case .dryYield: return "The dry flower this cycle aims to finish with"
        case .floweringWeeks: return "How long you want flowering to run"
        case .loggingCompleteness: return "The share of days you want on the record"
        }
    }

    var systemImage: String {
        switch self {
        case .dryYield: return "scalemass"
        case .floweringWeeks: return "camera.macro"
        case .loggingCompleteness: return "calendar.badge.checkmark"
        }
    }
}

/// The records a goal is measured against. Kept as one value so the
/// measurement is a pure function of what the store holds.
struct GrowGoalSources {
    var plants: [Plant] = []
    var rooms: [Room] = []
    var journal: [JournalEntry] = []
}

/// One measured value stated against the grower's own target.
struct GoalProgress: Identifiable {
    let kind: GrowGoalKind
    let unit: UnitSystem
    let target: Double
    let measured: Double?

    var id: String { kind.rawValue }

    var isMeasured: Bool { measured != nil }

    /// Nil while there is nothing to measure, so a bar is never drawn as zero
    /// progress for data the app does not have.
    var fraction: Double? {
        guard let measured, target > 0 else { return nil }
        return min(1, max(0, measured / target))
    }

    var measuredText: String {
        guard let measured else { return "Not measured yet" }
        switch kind {
        case .dryYield:
            return Format.weight(measured, unit: unit)
        case .floweringWeeks:
            return "\(Self.weeks(measured)) weeks"
        case .loggingCompleteness:
            return "\(Int(measured.rounded()))%"
        }
    }

    var targetText: String {
        switch kind {
        case .dryYield:
            return "target \(Format.weight(target, unit: unit))"
        case .floweringWeeks:
            return "target \(Self.weeks(target)) weeks"
        case .loggingCompleteness:
            return "target \(Int(target.rounded()))%"
        }
    }

    /// The whole statement for one target, for the row and for VoiceOver.
    var statusText: String {
        isMeasured ? "\(measuredText) · \(targetText)" : "Nothing to measure yet · \(targetText)"
    }

    private static func weeks(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }
}

enum GrowGoalError: LocalizedError {
    case invalidTarget

    var errorDescription: String? {
        switch self {
        case .invalidTarget:
            return "Enter a target above zero. Logging completeness is a share between 1 and 100 percent."
        }
    }
}

enum GrowGoalService {
    // MARK: Store

    /// The most recently edited goal record, or nil when none is set.
    static func current(from goals: [GrowGoal]) -> GrowGoal? {
        goals.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    /// Writes the three targets in one save. Saving with no target at all
    /// removes the stored record, so a goal can be taken back without leaving
    /// an empty row in the store, the export or the backup.
    @discardableResult
    static func save(
        dryYieldTargetGrams: Double?,
        floweringWeeksTarget: Int?,
        loggingCompletenessTargetPercent: Int?,
        existing: GrowGoal?,
        in context: ModelContext
    ) throws -> GrowGoal? {
        if let dryYieldTargetGrams, dryYieldTargetGrams <= 0 {
            throw GrowGoalError.invalidTarget
        }
        if let floweringWeeksTarget, floweringWeeksTarget <= 0 {
            throw GrowGoalError.invalidTarget
        }
        if let loggingCompletenessTargetPercent,
           !(1...100).contains(loggingCompletenessTargetPercent) {
            throw GrowGoalError.invalidTarget
        }

        let hasAnyTarget = dryYieldTargetGrams != nil
            || floweringWeeksTarget != nil
            || loggingCompletenessTargetPercent != nil

        do {
            guard hasAnyTarget else {
                if let existing {
                    context.delete(existing)
                }
                try context.save()
                return nil
            }

            let goal: GrowGoal
            if let existing {
                goal = existing
            } else {
                let created = GrowGoal(
                    dryYieldTargetGrams: dryYieldTargetGrams,
                    floweringWeeksTarget: floweringWeeksTarget,
                    loggingCompletenessTargetPercent: loggingCompletenessTargetPercent
                )
                context.insert(created)
                goal = created
            }

            goal.dryYieldTargetGrams = dryYieldTargetGrams
            goal.floweringWeeksTarget = floweringWeeksTarget
            goal.loggingCompletenessTargetPercent = loggingCompletenessTargetPercent
            goal.updatedAt = Date()

            try context.save()
            return goal
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Measurement

    /// One row per target the grower set, in a fixed order.
    static func progress(
        goal: GrowGoal?,
        sources: GrowGoalSources,
        unit: UnitSystem,
        now: Date = Date()
    ) -> [GoalProgress] {
        guard let goal else { return [] }

        var items: [GoalProgress] = []

        if let target = goal.dryYieldTargetGrams {
            items.append(
                GoalProgress(
                    kind: .dryYield,
                    unit: unit,
                    target: target,
                    measured: dryYieldGrams(from: sources.plants)
                )
            )
        }

        if let weeks = goal.floweringWeeksTarget {
            items.append(
                GoalProgress(
                    kind: .floweringWeeks,
                    unit: unit,
                    target: Double(weeks),
                    measured: averageFloweringWeeks(from: sources.plants)
                )
            )
        }

        if let percent = goal.loggingCompletenessTargetPercent {
            items.append(
                GoalProgress(
                    kind: .loggingCompleteness,
                    unit: unit,
                    target: Double(percent),
                    measured: loggingCompleteness(from: sources, now: now)
                )
            )
        }

        return items
    }

    /// Every recorded dry weight added up. Nil when no plant has one, so a
    /// missing figure is never presented as zero.
    static func dryYieldGrams(from plants: [Plant]) -> Double? {
        let weights = plants.compactMap(\.dryWeightGrams)
        return weights.isEmpty ? nil : weights.reduce(0, +)
    }

    /// The average observed flowering time of the plants that have finished
    /// flowering, in weeks. Nil when no plant has finished.
    static func averageFloweringWeeks(from plants: [Plant]) -> Double? {
        let durations = plants.compactMap(floweringDays)
        guard !durations.isEmpty else { return nil }
        let total = durations.reduce(0, +)
        return Double(total) / Double(durations.count) / 7
    }

    /// Days between entering flower and leaving it. Nil while the plant is
    /// still flowering, so a running stage is never counted as a result.
    static func floweringDays(for plant: Plant) -> Int? {
        let events = plant.sortedStageEvents
        guard let start = events.firstIndex(where: { $0.stage == .flower }) else {
            return nil
        }
        guard let next = events[(start + 1)...].first(where: { $0.stage != .flower }) else {
            return nil
        }

        let days = Calendar.current.dateComponents(
            [.day],
            from: events[start].date,
            to: next.date
        ).day ?? 0
        return max(0, days)
    }

    /// The share of days in the cycle carrying at least one record, 0–100.
    /// Nil when there is nothing recorded to measure.
    static func loggingCompleteness(
        from sources: GrowGoalSources,
        now: Date = Date()
    ) -> Double? {
        let calendar = Calendar.current
        var days: Set<Date> = []
        var earliest: Date?

        func note(_ date: Date) {
            days.insert(calendar.startOfDay(for: date))
            if let current = earliest {
                if date < current {
                    earliest = date
                }
            } else {
                earliest = date
            }
        }

        for plant in sources.plants {
            note(plant.plantedAt)
            plant.stageEvents.forEach { note($0.date) }
            plant.trainingSessions.forEach { note($0.date) }
            plant.treatments.forEach { note($0.date) }
            plant.scoutingChecks.forEach { note($0.date) }
            plant.dryingSessions.forEach { session in
                note(session.startedAt)
                session.checks.forEach { note($0.date) }
                session.burps.forEach { note($0.date) }
            }
            if let harvestedAt = plant.harvestedAt {
                note(harvestedAt)
            }
        }

        for room in sources.rooms {
            room.feedEvents.forEach { note($0.date) }
            room.environmentReadings.forEach { note($0.date) }
            room.calibrationEvents.forEach { note($0.date) }
            room.lightScheduleEvents.forEach { note($0.date) }
            room.treatments.forEach { note($0.date) }
            room.scoutingChecks.forEach { note($0.date) }
            room.environmentAlerts.forEach { note($0.detectedAt) }
        }

        sources.journal.forEach { note($0.createdAt) }

        guard let earliest else { return nil }

        let start = calendar.startOfDay(for: earliest)
        let end = calendar.startOfDay(for: now)
        let windowDays = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        guard windowDays > 0 else { return nil }

        return min(100, Double(days.count) / Double(windowDays) * 100)
    }
}
