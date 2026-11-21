//
//  StrainComparison.swift
//  Grow Companion
//
//  Side-by-side comparison of the cultivars the grower has actually finished.
//  Every figure is an average of their own harvested cycles, the sample size
//  travels with it, and a gap stays a gap: the breeder's label is never
//  substituted, so the comparison cannot read as a claim about a genotype.
//

import Foundation
import SwiftData

/// The measure the comparison puts side by side.
enum CultivarMetric: String, CaseIterable, Identifiable {
    case floweringDays
    case dryYieldGrams
    case rating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .floweringDays: return String(localized: "Flowering")
        case .dryYieldGrams: return String(localized: "Dry yield")
        case .rating: return String(localized: "Rating")
        }
    }

    var subtitle: String {
        switch self {
        case .floweringDays:
            return String(localized: "Days from the flower event to the harvest.")
        case .dryYieldGrams:
            return String(localized: "Dried weight of one plant.")
        case .rating:
            return String(localized: "Your 1–5 rating of the finished flower.")
        }
    }

    func value(of sample: CultivarSample) -> Double? {
        switch self {
        case .floweringDays: return sample.floweringDays.map(Double.init)
        case .dryYieldGrams: return sample.dryYieldGrams
        case .rating: return sample.rating
        }
    }

    func display(_ value: Double, unit: UnitSystem) -> String {
        switch self {
        case .floweringDays: return Format.dayCount(Int(value.rounded()))
        case .dryYieldGrams: return Format.weight(value, unit: unit)
        case .rating: return Format.number(value, digits: 1) + " / 5"
        }
    }
}

/// One cultivar's own results, with the number of finished cycles each average
/// rests on.
struct CultivarSample: Identifiable, Equatable {
    let name: String
    let strainID: PersistentIdentifier?
    /// Harvested plants, which are the only ones averaged.
    let cycles: Int
    /// Plants of this cultivar still growing.
    let inProgress: Int
    let floweringDays: Int?
    let floweringSamples: Int
    let dryYieldGrams: Double?
    let yieldSamples: Int
    let rating: Double?
    let ratingSamples: Int

    var id: String { name }

    /// One harvest is a single run, not a pattern.
    var isSingleCycle: Bool { cycles == 1 }

    var sampleText: String {
        cycles == 1
            ? String(localized: "1 cycle")
            : String(localized: "\(cycles) cycles")
    }

    var inProgressText: String? {
        guard inProgress > 0 else { return nil }
        return inProgress == 1
            ? String(localized: "1 in progress")
            : String(localized: "\(inProgress) in progress")
    }
}

enum StrainComparison {
    /// The name a plant is compared under, or nil when it was never given one.
    static func cultivarName(for plant: Plant) -> String? {
        if let strain = plant.strain {
            let trimmed = strain.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let trimmed = plant.strainName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Every cultivar the grower has plants for, grouped by name, largest
    /// sample first. Only harvested plants feed the averages.
    static func samples(from plants: [Plant]) -> [CultivarSample] {
        var buckets: [String: Bucket] = [:]

        for plant in plants {
            guard let name = cultivarName(for: plant) else { continue }
            let key = foldedKey(name)
            var bucket = buckets[key] ?? Bucket(name: name, strainID: plant.strain?.persistentModelID)
            if bucket.strainID == nil {
                bucket.strainID = plant.strain?.persistentModelID
            }
            if CycleMetrics.isFinished(plant) {
                bucket.finished.append(plant)
            } else {
                bucket.inProgress.append(plant)
            }
            buckets[key] = bucket
        }

        return buckets.values
            .map(makeSample)
            .sorted { lhs, rhs in
                if lhs.cycles != rhs.cycles { return lhs.cycles > rhs.cycles }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// The cultivars that have a value for one measure, which is what a chart
    /// can draw. A cultivar with no figure is left out, never drawn as zero.
    static func samples(_ samples: [CultivarSample], with metric: CultivarMetric) -> [CultivarSample] {
        samples.filter { metric.value(of: $0) != nil }
    }

    static func hasEnoughToCompare(_ samples: [CultivarSample]) -> Bool {
        samples.filter { $0.cycles > 0 }.count >= 2
    }

    /// A short sentence for the chart's text equivalent and the row.
    static func summary(for sample: CultivarSample) -> String {
        [
            sample.sampleText,
            sample.inProgressText
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    // MARK: Internals

    private struct Bucket {
        let name: String
        var strainID: PersistentIdentifier?
        var finished: [Plant] = []
        var inProgress: [Plant] = []
    }

    private static func makeSample(_ bucket: Bucket) -> CultivarSample {
        let flowering = bucket.finished.compactMap { StrainInsights.floweringDays(for: $0) }
        let yields = bucket.finished.compactMap(\.dryWeightGrams)
        let ratings = bucket.finished.compactMap { $0.rating.map(Double.init) }

        return CultivarSample(
            name: bucket.name,
            strainID: bucket.strainID,
            cycles: bucket.finished.count,
            inProgress: bucket.inProgress.count,
            floweringDays: mean(flowering.map(Double.init)).map { Int($0.rounded()) },
            floweringSamples: flowering.count,
            dryYieldGrams: mean(yields),
            yieldSamples: yields.count,
            rating: mean(ratings),
            ratingSamples: ratings.count
        )
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func foldedKey(_ name: String) -> String {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
