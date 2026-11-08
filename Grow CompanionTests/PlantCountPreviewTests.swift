//
//  PlantCountPreviewTests.swift
//  Grow CompanionTests
//
//  The pre-save count shown when a plant is added: what the jurisdiction would
//  count with the new plant, and when that crosses the limit.
//

import Foundation
import SwiftData
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct PlantCountPreviewTests {
    @Test func addingASeedCountsOne() throws {
        let context = try previewContext()
        let rule = testRule(countedStages: [.seed, .veg, .flower], plantLimit: 3)

        let existing = Plant(name: "One", stage: .veg)
        context.insert(existing)
        try context.save()

        let preview = QuickLogService.countPreview(
            addingStage: .seed,
            plants: [existing],
            rule: rule,
            warningThreshold: 0.8
        )

        #expect(preview.countedBefore == 1)
        #expect(preview.countedAfter == 2)
        #expect(preview.isOverLimit == false)
    }

    @Test func addingACloneIsNotCountedWhenTheRuleExcludesClones() throws {
        let context = try previewContext()
        let rule = testRule(countedStages: [.seed, .veg, .flower], plantLimit: 3)

        let preview = QuickLogService.countPreview(
            addingStage: .clone,
            plants: [],
            rule: rule,
            warningThreshold: 0.8
        )

        #expect(preview.countedBefore == 0)
        #expect(preview.countedAfter == 0)
        #expect(preview.isOverLimit == false)
    }

    @Test func addingACloneCountsWhenTheRuleIncludesThem() throws {
        let context = try previewContext()
        let rule = testRule(countedStages: [.clone, .veg, .flower], plantLimit: 3, countsClones: true)

        let preview = QuickLogService.countPreview(
            addingStage: .clone,
            plants: [],
            rule: rule,
            warningThreshold: 0.8
        )

        #expect(preview.countedAfter == 1)
    }

    @Test func addingOverTheLimitIsFlaggedAndBlocked() throws {
        let context = try previewContext()
        let rule = testRule(countedStages: [.seed, .veg, .flower], plantLimit: 2)

        let first = Plant(name: "One", stage: .veg)
        let second = Plant(name: "Two", stage: .flower)
        context.insert(first)
        context.insert(second)
        try context.save()

        let preview = QuickLogService.countPreview(
            addingStage: .seed,
            plants: [first, second],
            rule: rule,
            warningThreshold: 0.8
        )

        #expect(preview.countedBefore == 2)
        #expect(preview.countedAfter == 3)
        #expect(preview.isOverLimit == true)
        #expect(preview.level == .over)
    }

    @Test func aRuleWithoutALimitIsNeverOver() throws {
        let context = try previewContext()
        let rule = testRule(countedStages: [.veg, .flower], plantLimit: nil)

        let preview = QuickLogService.countPreview(
            addingStage: .veg,
            plants: [],
            rule: rule,
            warningThreshold: 0.8
        )

        #expect(preview.plantLimit == nil)
        #expect(preview.isOverLimit == false)
    }

    @Test func destroyedPlantsAreNotCounted() throws {
        let context = try previewContext()
        let rule = testRule(countedStages: [.flower], plantLimit: 2)

        let destroyed = Plant(name: "Gone", stage: .flower)
        destroyed.harvestDisposition = .destroyed
        context.insert(destroyed)
        try context.save()

        let preview = QuickLogService.countPreview(
            addingStage: .flower,
            plants: [destroyed],
            rule: rule,
            warningThreshold: 0.8
        )

        #expect(preview.countedBefore == 0)
        #expect(preview.countedAfter == 1)
    }

    @Test func anUncultivableJurisdictionCountsNothing() throws {
        let context = try previewContext()
        let rule = testRule(countedStages: [.veg, .flower], plantLimit: 2, cultivable: false)

        let preview = QuickLogService.countPreview(
            addingStage: .veg,
            plants: [Plant(name: "One", stage: .veg)],
            rule: rule,
            warningThreshold: 0.8
        )

        #expect(preview.countedAfter == 0)
        #expect(preview.isOverLimit == false)
    }

    // MARK: Support

    private func previewContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DataInventory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func testRule(
        countedStages: [PlantStage],
        plantLimit: Int?,
        countsClones: Bool = false,
        cultivable: Bool = true
    ) -> JurisdictionRule {
        JurisdictionRule(
            stateCode: "TS",
            stateName: "Test",
            cultivable: cultivable,
            plantLimit: plantLimit,
            countedStages: countedStages,
            countsClones: countsClones,
            countingNote: "Vegetative and flowering plants count.",
            summary: "Test rule",
            citation: "Test citation",
            sourceURL: ""
        )
    }
}
