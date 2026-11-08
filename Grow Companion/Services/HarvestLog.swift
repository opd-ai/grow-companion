//
//  HarvestLog.swift
//  Grow Companion
//
//  Dry-weight prediction from the grower's own history, yield per watt, the
//  progressive burping schedule, mold-risk checks and the drying guidance.
//

import Foundation
import SwiftData

struct DryPrediction {
    let grams: Double
    let ratio: Double
    let sampleCount: Int

    var basisText: String {
        if sampleCount > 0 {
            return "From your history: \(sampleCount) harvest\(sampleCount == 1 ? "" : "s") averaged \(Int((ratio * 100).rounded()))% dry-to-wet."
        }
        return "From the default 22% dry-to-wet ratio. Your own ratio takes over as you record harvests."
    }
}

struct DryingRisk {
    enum Kind {
        case mold
        case fastDry
        case heat
    }

    let kind: Kind
    let title: String
    let message: String
    let checklist: [String]

    var isCritical: Bool { kind == .mold }
}

enum HarvestLog {
    static let defaultRatio = 0.22

    // MARK: Dry prediction

    static func historicalRatio(plants: [Plant]) -> (ratio: Double, sampleCount: Int)? {
        let ratios = plants.compactMap { plant -> Double? in
            guard let wet = plant.wetWeightGrams, wet > 0,
                  let dry = plant.dryWeightGrams, dry > 0 else { return nil }
            return dry / wet
        }
        guard !ratios.isEmpty else { return nil }
        return (ratios.reduce(0, +) / Double(ratios.count), ratios.count)
    }

    static func predict(plants: [Plant], wetGrams: Double) -> DryPrediction {
        if let history = historicalRatio(plants: plants) {
            return DryPrediction(
                grams: wetGrams * history.ratio,
                ratio: history.ratio,
                sampleCount: history.sampleCount
            )
        }
        return DryPrediction(
            grams: wetGrams * defaultRatio,
            ratio: defaultRatio,
            sampleCount: 0
        )
    }

    static func gramsPerWatt(dryGrams: Double?, watts: Int) -> Double? {
        guard let dryGrams, dryGrams > 0, watts > 0 else { return nil }
        return dryGrams / Double(watts)
    }

    // MARK: Timing

    static func dayCount(since date: Date, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    static func dryingDay(_ session: DryingSession, now: Date = Date()) -> Int {
        dayCount(since: session.startedAt, now: now) + 1
    }

    static func curingDay(_ session: DryingSession, now: Date = Date()) -> Int? {
        guard let start = session.curingStartedAt else { return nil }
        return dayCount(since: start, now: now) + 1
    }

    static func dryingDayText(_ session: DryingSession, now: Date = Date()) -> String {
        let expected = session.profile.expectedDryDays
        let day = dryingDay(session, now: now)
        if day < expected.lowerBound {
            return "Day \(day) of about \(expected.lowerBound)–\(expected.upperBound)"
        }
        if day <= expected.upperBound {
            return "Day \(day) · in the harvest window"
        }
        return "Day \(day) · longer than usual"
    }

    static func curingDayText(_ session: DryingSession, now: Date = Date()) -> String {
        let day = curingDay(session, now: now) ?? 1
        return "Day \(day) of curing"
    }

    // MARK: Burping

    static func nextBurpDate(_ session: DryingSession, now: Date = Date()) -> Date? {
        guard session.phase == .curing, let start = session.curingStartedAt else { return nil }
        let base = session.lastBurpedAt ?? start
        let day = curingDay(session, now: now) ?? 1
        let interval = session.burpMode.intervalDays(curingDay: day)
        return Calendar.current.date(byAdding: .day, value: interval, to: base)
    }

    static func logBurp(_ session: DryingSession, context: ModelContext, now: Date = Date()) {
        let burp = CureBurp(date: now)
        context.insert(burp)
        burp.session = session
        session.lastBurpedAt = now
        try? context.save()
        scheduleBurpNotification(session)
    }

    static func scheduleBurpNotification(_ session: DryingSession) {
        guard session.phase == .curing, let next = nextBurpDate(session) else {
            CareNotifications.cancel(identifier: session.burpNotificationIdentifier)
            return
        }
        CareNotifications.schedule(
            identifier: session.burpNotificationIdentifier,
            title: "Curing check due",
            body: "Open Grow Companion to burp the jars.",
            at: next
        )
    }

    // MARK: Risk

    static func risk(
        for check: DryingCheck,
        session: DryingSession
    ) -> DryingRisk? {
        risk(session: session, humidity: check.humidityPercent, temperature: check.temperatureC)
    }

    static func risk(
        session: DryingSession,
        humidity: Double?,
        temperature: Double?
    ) -> DryingRisk? {
        let humidityRange = session.phase == .curing
            ? session.curingHumidityRange
            : session.targetHumidityRange
        let temperatureRange = session.targetTemperatureRange

        if let humidity {
            if humidity > humidityRange.upperBound + 3 {
                return DryingRisk(
                    kind: .mold,
                    title: "Mold risk",
                    message: "Humidity is \(String(format: "%.0f%%", humidity)) — above the safe band of \(String(format: "%.0f–%.0f%%", humidityRange.lowerBound, humidityRange.upperBound)).",
                    checklist: [
                        "Increase gentle airflow across the buds.",
                        "Open dense buds and look for grey fuzz or a musty smell.",
                        "Remove anything affected and clean the space.",
                        "Get humidity back under \(String(format: "%.0f%%", humidityRange.upperBound)) before it sits overnight."
                    ]
                )
            }
            if humidity < humidityRange.lowerBound - 3 {
                return DryingRisk(
                    kind: .fastDry,
                    title: "Drying too fast",
                    message: "Humidity is \(String(format: "%.0f%%", humidity)) — below the safe band of \(String(format: "%.0f–%.0f%%", humidityRange.lowerBound, humidityRange.upperBound)).",
                    checklist: [
                        "Lower airflow or fan speed.",
                        "Hang buds closer together or use a smaller space.",
                        "Check again in 12 hours.",
                        "Bring humidity back into the target band before it dries past the point of curing."
                    ]
                )
            }
        }

        if let temperature, temperature > temperatureRange.upperBound + 3 {
            return DryingRisk(
                kind: .heat,
                title: "Too warm",
                message: "Temperature is \(String(format: "%.1f °C", temperature)) — above the target band of \(String(format: "%.0f–%.0f °C", temperatureRange.lowerBound, temperatureRange.upperBound)).",
                checklist: [
                    "Move the space out of direct light.",
                    "Lower the room temperature toward the target band.",
                    "Keep gentle airflow moving.",
                    "Re-check in a few hours."
                ]
            )
        }

        return nil
    }

    // MARK: Checks

    static func checksByDay(_ session: DryingSession, days: Int = 7) -> [(date: Date, check: DryingCheck?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return (today, nil)
            }
            let match = session.sortedChecks.last { check in
                calendar.isDate(check.date, inSameDayAs: day)
            }
            return (day, match)
        }
    }

    static func checkSummary(_ check: DryingCheck, dayNumber: Int) -> String {
        var parts: [String] = ["Day \(dayNumber)"]
        if let humidity = check.humidityPercent {
            parts.append(String(format: "%.0f%%", humidity))
        }
        if let temperature = check.temperatureC {
            parts.append(String(format: "%.1f °C", temperature))
        }
        if let stem = check.stemSnap {
            parts.append(stem.title.lowercased())
        }
        return parts.joined(separator: " · ")
    }

    static func dayNumber(for check: DryingCheck, in session: DryingSession) -> Int {
        if session.phase == .curing {
            guard let start = session.curingStartedAt else { return 1 }
            return dayCount(since: start, now: check.date) + 1
        }
        return dayCount(since: session.startedAt, now: check.date) + 1
    }
}
