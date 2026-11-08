//
//  CultivationSchema.swift
//  Grow Companion
//
//  The explicit, versioned cultivation store. V1 freezes the model set that
//  shipped before compliance history; V2 adds the two append-only compliance
//  records; V3 adds the grower's own cycle goals. Every migration is additive
//  and lightweight: no existing model, relationship, identifier or value is
//  rewritten.
//

import Foundation
import SwiftData

enum CultivationSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    /// The model set that shipped with the unversioned store, frozen exactly.
    static let legacyModels: [any PersistentModel.Type] = [
        GrowProfile.self,
        Room.self,
        Plant.self,
        CycleArchive.self,
        Strain.self,
        StageEvent.self,
        JournalEntry.self,
        LightScheduleEvent.self,
        EnvironmentReading.self,
        SensorDevice.self,
        ShareGrant.self,
        ShareAccessLog.self,
        EnvironmentAlert.self,
        FeedEvent.self,
        CalibrationEvent.self,
        CareReminder.self,
        DryingSession.self,
        DryingCheck.self,
        CureBurp.self,
        TrainingSession.self,
        Treatment.self,
        Equipment.self,
        ServiceRecord.self,
        ScoutingCheck.self,
        FeedSchedule.self,
        FeedWeek.self,
        FeedProduct.self
    ]

    static var models: [any PersistentModel.Type] { legacyModels }
}

enum CultivationSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        CultivationSchemaV1.legacyModels + [
            ComplianceSnapshot.self,
            RuleEvaluationEvent.self
        ]
    }
}

enum CultivationSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        CultivationSchemaV2.models + [GrowGoal.self]
    }
}

enum CultivationMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CultivationSchemaV1.self, CultivationSchemaV2.self, CultivationSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: CultivationSchemaV1.self,
                toVersion: CultivationSchemaV2.self
            ),
            .lightweight(
                fromVersion: CultivationSchemaV2.self,
                toVersion: CultivationSchemaV3.self
            )
        ]
    }
}
