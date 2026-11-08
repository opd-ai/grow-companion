//
//  GrowGoal.swift
//  Grow Companion
//
//  The grower's own optional targets for the current cycle: a dry yield, a
//  flowering time and a logging completeness. Local only, editable at any
//  time, and never used to grade the grow or to compare it with anyone else's.
//

import Foundation
import SwiftData

@Model
final class GrowGoal {
    /// Dry flower this cycle aims to finish with, in grams.
    var dryYieldTargetGrams: Double?

    /// How long flowering should run, in weeks.
    var floweringWeeksTarget: Int?

    /// The share of days the grower wants on the record, 1–100.
    var loggingCompletenessTargetPercent: Int?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        dryYieldTargetGrams: Double? = nil,
        floweringWeeksTarget: Int? = nil,
        loggingCompletenessTargetPercent: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.dryYieldTargetGrams = dryYieldTargetGrams
        self.floweringWeeksTarget = floweringWeeksTarget
        self.loggingCompletenessTargetPercent = loggingCompletenessTargetPercent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// True while at least one of the three targets is set.
    var hasAnyTarget: Bool {
        dryYieldTargetGrams != nil
            || floweringWeeksTarget != nil
            || loggingCompletenessTargetPercent != nil
    }
}
