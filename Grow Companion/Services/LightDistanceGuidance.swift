//
//  LightDistanceGuidance.swift
//  Grow Companion
//
//  The distance guidance the room card and the measurement sheet read: the
//  cited per-fixture band for the room's stage, the grower's own target when it
//  replaces the app's figure, where a measured distance sits, and when taking a
//  new measurement is worth doing. Pure value types, so every rule here is
//  testable without a store or a view.
//

import Foundation

/// A cited distance band for one room and stage, in metres.
struct LightDistanceTarget: Hashable {
    let range: ClosedRange<Double>
    let source: String
    let reviewedOn: Date
    /// True when the grower replaced the app's figure with their own.
    let isGrowerSet: Bool
}

/// Where a reading sits against the target band.
enum LightDistanceStatus: Hashable {
    case closer
    case inside
    case over
    case noTarget
}

/// Why a fresh measurement is worth taking.
enum LightDistanceReason: Hashable {
    case neverMeasured
    case stageChanged(from: PlantStage, to: PlantStage)
    case trained(daysAgo: Int)
    case stale(days: Int)
}

struct LightDistanceAdvice: Equatable {
    let range: ClosedRange<Double>
    let isUserSet: Bool
    let summary: String
    let detail: String
}

enum LightDistanceService {
    /// Below this the plants are too close to a hot fixture; above it the light
    /// is too far away to be useful.
    static let minimumMeters = 0.10
    static let maximumMeters = 3.0

    /// The bands are general manufacturer guidance, not a rule for any fixture.
    static let reviewDate = date(year: 2025, month: 5, day: 15)

    static func advice(
        for stage: PlantStage,
        fixture: LightFixtureType,
        userSetMeters: ClosedRange<Double>? = nil
    ) -> LightDistanceAdvice? {
        if let userSet = clamped(userSetMeters) {
            return LightDistanceAdvice(
                range: userSet,
                isUserSet: true,
                summary: String(localized: "Your own target for this fixture"),
                detail: String(localized: "Set by you, so the stage factor is not applied. The fixture manual stays the authority.")
            )
        }
        guard let raw = fixture.targetRangeMeters else { return nil }
        let band = stageBand(for: stage, base: raw)
        guard let clampedBand = clamped(band) else { return nil }
        return LightDistanceAdvice(
            range: clampedBand,
            isUserSet: false,
            summary: fixture.guidanceSource,
            detail: stageDetail(for: stage)
        )
    }

    static func band(for stage: PlantStage, fixture: LightFixtureType) -> ClosedRange<Double>? {
        guard let raw = fixture.targetRangeMeters else { return nil }
        return clamped(stageBand(for: stage, base: raw))
    }

    /// Seedlings and clones stay farther from the fixture than a flowering
    /// canopy, so they read the top of the band pushed out by the seedling
    /// factor. Vegetative plants sit a little above the base band.
    static func stageBand(for stage: PlantStage, base: ClosedRange<Double>) -> ClosedRange<Double> {
        switch stage {
        case .seed, .clone:
            let lower = base.upperBound * 0.95
            let upper = base.upperBound * 1.35
            return min(lower, upper)...max(lower, upper)
        case .veg:
            return (base.lowerBound * 1.10)...(base.upperBound * 1.15)
        case .flower, .harvest, .cure, .storage:
            return base
        }
    }

    static func stageDetail(for stage: PlantStage) -> String {
        switch stage {
        case .seed, .clone:
            return String(localized: "Seedlings keep more distance until they harden off.")
        case .veg:
            return String(localized: "Read this from the top of the canopy, not the pot.")
        case .flower, .harvest, .cure, .storage:
            return String(localized: "Canopy height changes through training.")
        }
    }

    /// `closer`, `inside` or `over` the band. An unknown fixture has no target.
    static func status(distance: Double?, target: LightDistanceAdvice?) -> LightDistanceStatus {
        guard let distance, distance.isFinite, distance > 0 else { return .noTarget }
        guard let target else { return .noTarget }
        if target.range.contains(distance) { return .inside }
        return distance < target.range.lowerBound ? .closer : .over
    }

    static func statusTitle(_ status: LightDistanceStatus) -> String {
        switch status {
        case .closer: return String(localized: "Too close")
        case .inside: return String(localized: "Inside range")
        case .over: return String(localized: "Too far")
        case .noTarget: return String(localized: "No target")
        }
    }

    /// Why a new measurement is worth taking.
    ///
    /// Order matters: a missing measurement is the largest gap, then a stage
    /// change, then training that moved the canopy, then age. Training is
    /// counted after the reading and requires at least one session.
    static func reMeasureReason(
        measuredMeters: Double?,
        measuredAt: Date?,
        measuredStage: PlantStage?,
        currentStage: PlantStage?,
        trainingDates: [Date],
        now: Date = Date(),
        staleAfterDays: Int = 14
    ) -> LightDistanceReason? {
        guard measuredMeters != nil, let measuredAt else { return .neverMeasured }
        if let measuredStage, let currentStage, measuredStage != currentStage {
            return .stageChanged(from: measuredStage, to: currentStage)
        }
        let trainedAfter = trainingDates.filter { $0 > measuredAt }.count
        if trainedAfter > 0 {
            let days = Calendar.current.dateComponents([.day], from: measuredAt, to: now).day ?? 0
            return .trained(daysAgo: max(days, 0))
        }
        let days = Calendar.current.dateComponents([.day], from: measuredAt, to: now).day ?? 0
        if days >= staleAfterDays { return .stale(days: days) }
        return nil
    }

    static func reMeasureTitle(_ reason: LightDistanceReason) -> String {
        switch reason {
        case .neverMeasured: return String(localized: "Measure the canopy")
        case .stageChanged: return String(localized: "Re-measure: the stage changed")
        case .trained: return String(localized: "Re-measure after training")
        case .stale: return String(localized: "Re-measure: the reading is old")
        }
    }

    static func reMeasureDetail(_ reason: LightDistanceReason) -> String {
        switch reason {
        case .neverMeasured:
            return String(localized: "No distance has been confirmed for this room yet.")
        case let .stageChanged(from, to):
            return String(localized: "The room moved from \(from.title.lowercased()) to \(to.title.lowercased()) since the last measurement.")
        case let .trained(daysAgo):
            return daysAgo == 1
                ? String(localized: "Training was recorded the day after the last measurement.")
                : String(localized: "Training was recorded after the last measurement, \(daysAgo) days ago.")
        case let .stale(days):
            return String(localized: "The last measurement is \(days) days old.")
        }
    }

    private static func clamped(_ range: ClosedRange<Double>?) -> ClosedRange<Double>? {
        guard let range else { return nil }
        let low = max(minimumMeters, min(range.lowerBound, maximumMeters))
        let high = max(minimumMeters, min(range.upperBound, maximumMeters))
        guard low < high else { return nil }
        return low...high
    }

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 1_747_267_200)
    }
}

// MARK: - Room glue

extension Room {
    /// The target band the room's light card and sheet show.
    var lightDistanceAdvice: LightDistanceAdvice? {
        LightDistanceService.advice(
            for: dominantStage ?? .veg,
            fixture: lightFixture,
            userSetMeters: growerSetLightTargetRange
        )
    }

    /// Why a new canopy measurement is worth taking, if it is.
    var lightDistanceReason: LightDistanceReason? {
        LightDistanceService.reMeasureReason(
            measuredMeters: canopyDistanceMeters,
            measuredAt: canopyDistanceMeasuredAt,
            measuredStage: canopyDistanceStage,
            currentStage: dominantStage,
            trainingDates: plants.flatMap { $0.trainingSessions.map(\.date) }
        )
    }
}

// MARK: - Unit helpers

extension Format {
    /// A single distance in the grower's unit: `45 cm` or `18 in`.
    static func distance(_ meters: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric: return number(meters * 100, digits: 0) + " cm"
        case .imperial: return number(meters * 39.3701, digits: 0) + " in"
        }
    }

    static func distanceRange(_ range: ClosedRange<Double>, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return number(range.lowerBound * 100, digits: 0) + "–" + number(range.upperBound * 100, digits: 0) + " cm"
        case .imperial:
            return number(range.lowerBound * 39.3701, digits: 0) + "–" + number(range.upperBound * 39.3701, digits: 0) + " in"
        }
    }

    /// The unit symbol a typed distance is entered in.
    static func distanceUnit(_ unit: UnitSystem) -> String {
        unit == .metric ? "cm" : "in"
    }

    /// A distance as a plain number in the grower's unit, for a text field.
    static func distanceEntryText(_ meters: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric: return number(meters * 100, digits: 0)
        case .imperial: return number(meters * 39.3701, digits: 0)
        }
    }

    /// Reads a typed distance in the grower's unit and returns metres, or nil
    /// when the text is not a positive, plausible distance.
    static func meters(fromEntry text: String, unit: UnitSystem) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let value = Double(normalized), value.isFinite, value > 0 else {
            return nil
        }
        let meters = unit == .metric ? value / 100 : value * 0.0254
        guard meters >= 0.02, meters <= 10 else { return nil }
        return meters
    }
}
