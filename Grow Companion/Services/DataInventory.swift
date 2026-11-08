//
//  DataInventory.swift
//  Grow Companion
//
//  The single inventory of every record type the app stores. Export, backup,
//  restore, delete-all and the coverage tests all read the same list, so a new
//  @Model cannot be added to the schema and then quietly left out of the data
//  controls.
//

import Foundation
import SwiftData

/// A model's name with the two operations the data controls need from it.
struct ModelProbe {
    let name: String
    let count: (ModelContext) -> Int
    let delete: (ModelContext) throws -> Void
}

/// One non-empty model count, for the export manifest and the erase summary.
struct ModelCount: Identifiable, Hashable {
    let name: String
    let count: Int

    var id: String { name }
    var label: String { DataInventory.label(for: name) }
}

enum DataInventory {
    /// Every model registered in the container, in the order the versioned
    /// schema lists it. `CultivationSchemaV2` is the single source for the list.
    static var models: [any PersistentModel.Type] { CultivationSchemaV2.models }

    static var schema: Schema { Schema(versionedSchema: CultivationSchemaV2.self) }

    /// The name each model is counted, exported and reported under.
    static var modelNames: [String] {
        models.map { String(describing: $0) }
    }

    /// Human label for a model name, for the manifest and the erase summary.
    static func label(for modelName: String) -> String {
        labels[modelName] ?? modelName
    }

    /// Counts and deletes in the same order: children before parents.
    /// `deleteAll` walks this list, so nothing counted can be left behind.
    static let probes: [ModelProbe] = [
        probe(ComplianceSnapshot.self),
        probe(RuleEvaluationEvent.self),
        probe(DryingCheck.self),
        probe(CureBurp.self),
        probe(DryingSession.self),
        probe(TrainingSession.self),
        probe(ScoutingCheck.self),
        probe(EnvironmentAlert.self),
        probe(ServiceRecord.self),
        probe(Equipment.self),
        probe(Treatment.self),
        probe(FeedProduct.self),
        probe(FeedWeek.self),
        probe(FeedSchedule.self),
        probe(ShareAccessLog.self),
        probe(ShareGrant.self),
        probe(StageEvent.self),
        probe(JournalEntry.self),
        probe(EnvironmentReading.self),
        probe(FeedEvent.self),
        probe(CalibrationEvent.self),
        probe(LightScheduleEvent.self),
        probe(CareReminder.self),
        probe(SensorDevice.self),
        probe(CycleArchive.self),
        probe(Plant.self),
        probe(Room.self),
        probe(Strain.self),
        probe(GrowProfile.self)
    ]

    static func counts(in context: ModelContext) -> [String: Int] {
        var result: [String: Int] = [:]
        for entry in probes {
            result[entry.name] = entry.count(context)
        }
        return result
    }

    static func total(of counts: [String: Int]) -> Int {
        counts.values.reduce(0, +)
    }

    /// Counts above zero, largest first, for a manifest that stays readable.
    static func nonEmpty(from counts: [String: Int]) -> [ModelCount] {
        counts
            .filter { $0.value > 0 }
            .sorted { ($0.value, label(for: $0.key)) > ($1.value, label(for: $1.key)) }
            .map { ModelCount(name: $0.key, count: $0.value) }
    }

    /// Deletes every model in the inventory and returns the counts that remain,
    /// which a verified delete-all should leave all zero.
    @discardableResult
    static func deleteAll(in context: ModelContext) throws -> [String: Int] {
        for entry in probes {
            try entry.delete(context)
        }
        try context.save()
        return counts(in: context)
    }

    private static func probe<T: PersistentModel>(_ type: T.Type) -> ModelProbe {
        ModelProbe(
            name: String(describing: type),
            count: { context in (try? context.fetchCount(FetchDescriptor<T>())) ?? 0 },
            delete: { context in try context.delete(model: T.self) }
        )
    }

    private static let labels: [String: String] = [
        "ComplianceSnapshot": "Compliance history snapshots",
        "RuleEvaluationEvent": "Rule change reviews",
        "GrowProfile": "Grow profile and onboarding answers",
        "Room": "Rooms",
        "Plant": "Plants",
        "CycleArchive": "Cycle archives",
        "Strain": "Strains",
        "StageEvent": "Stage history",
        "JournalEntry": "Journal entries",
        "LightScheduleEvent": "Light schedule changes",
        "EnvironmentReading": "Environment readings",
        "SensorDevice": "Paired sensors",
        "ShareGrant": "Sharing configurations",
        "ShareAccessLog": "Sharing access log",
        "EnvironmentAlert": "Environment alerts",
        "FeedEvent": "Feed and watering events",
        "CalibrationEvent": "Calibrations",
        "CareReminder": "Care reminders",
        "DryingSession": "Drying and curing sessions",
        "DryingCheck": "Drying checks",
        "CureBurp": "Curing burp records",
        "TrainingSession": "Training sessions",
        "Treatment": "Treatments",
        "Equipment": "Equipment",
        "ServiceRecord": "Service history",
        "ScoutingCheck": "Scouting checks",
        "FeedSchedule": "Feed schedules",
        "FeedWeek": "Feed schedule weeks",
        "FeedProduct": "Feed schedule products"
    ]
}

/// The preferences delete-all clears. Kept in one place so the erase flow and
/// the tests agree on what counts as app-owned state.
enum DataControlPreferences {
    static func resetToDefaults() {
        NotificationSettings.resetToDefaults()

        for key in SettingsKey.all {
            UserDefaults.standard.removeObject(forKey: key)
        }

        for category in NotificationCategory.allCases {
            UserDefaults.standard.removeObject(
                forKey: SettingsKey.notificationPriorityPrefix + category.rawValue
            )
        }
    }
}
