//
//  DryingSession.swift
//  Grow Companion
//
//  One plant's dry and cure: the profile, the target bands, the daily checks
//  and the burping schedule.
//

import Foundation
import SwiftData

enum DryingPhase: String, CaseIterable, Identifiable {
    case drying
    case curing
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drying: return String(localized: "Drying")
        case .curing: return String(localized: "Curing")
        case .finished: return String(localized: "Finished")
        }
    }
}

enum DryingProfile: String, CaseIterable, Identifiable {
    case hangDry
    case rapidDry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hangDry: return String(localized: "Hang dry")
        case .rapidDry: return String(localized: "Rapid dry")
        }
    }

    var subtitle: String {
        switch self {
        case .hangDry: return String(localized: "Cool and slow · 18–21 °C, 58–62%")
        case .rapidDry: return String(localized: "Faster, higher risk · 21–24 °C, 50–55%")
        }
    }

    var temperatureRange: ClosedRange<Double> {
        switch self {
        case .hangDry: return 18...21
        case .rapidDry: return 21...24
        }
    }

    var humidityRange: ClosedRange<Double> {
        switch self {
        case .hangDry: return 58...62
        case .rapidDry: return 50...55
        }
    }

    var expectedDryDays: ClosedRange<Int> {
        switch self {
        case .hangDry: return 10...14
        case .rapidDry: return 5...7
        }
    }
}

enum BurpMode: String, CaseIterable, Identifiable {
    case progressive
    case daily
    case everyTwoDays
    case everyThreeDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .progressive: return String(localized: "Progressive")
        case .daily: return String(localized: "Every day")
        case .everyTwoDays: return String(localized: "Every 2 days")
        case .everyThreeDays: return String(localized: "Every 3 days")
        }
    }

    var subtitle: String {
        switch self {
        case .progressive: return String(localized: "Daily in week one, then every 2–3 days")
        case .daily: return String(localized: "Open the jars once a day")
        case .everyTwoDays: return String(localized: "Open the jars every other day")
        case .everyThreeDays: return String(localized: "Open the jars every third day")
        }
    }

    func intervalDays(curingDay: Int) -> Int {
        switch self {
        case .daily: return 1
        case .everyTwoDays: return 2
        case .everyThreeDays: return 3
        case .progressive:
            if curingDay <= 7 { return 1 }
            if curingDay <= 14 { return 2 }
            return 3
        }
    }
}

enum StemSnap: String, CaseIterable, Identifiable {
    case bends
    case cracks
    case snaps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bends: return String(localized: "Stems bend")
        case .cracks: return String(localized: "Stems crack")
        case .snaps: return String(localized: "Snap cleanly")
        }
    }

    var detail: String {
        switch self {
        case .bends: return String(localized: "Still wet — keep drying")
        case .cracks: return String(localized: "Getting close")
        case .snaps: return String(localized: "Ready to cure")
        }
    }
}

@Model
final class DryingSession {
    var startedAt: Date = Date()
    var phaseRaw: String = DryingPhase.drying.rawValue
    var profileRaw: String = DryingProfile.hangDry.rawValue

    var targetTemperatureLow: Double = 18
    var targetTemperatureHigh: Double = 21
    var targetHumidityLow: Double = 58
    var targetHumidityHigh: Double = 62

    var curingStartedAt: Date?
    var curingHumidityLow: Double = 58
    var curingHumidityHigh: Double = 62

    var burpModeRaw: String = BurpMode.progressive.rawValue
    var lastBurpedAt: Date?
    var burpNotificationIdentifier: String = UUID().uuidString
    var endedAt: Date?

    var plant: Plant?

    @Relationship(deleteRule: .cascade, inverse: \DryingCheck.session)
    var checks: [DryingCheck] = []

    @Relationship(deleteRule: .cascade, inverse: \CureBurp.session)
    var burps: [CureBurp] = []

    init(
        startedAt: Date = Date(),
        phase: DryingPhase = .drying,
        profile: DryingProfile = .hangDry,
        plant: Plant? = nil
    ) {
        self.startedAt = startedAt
        self.phaseRaw = phase.rawValue
        self.profileRaw = profile.rawValue
        self.plant = plant

        let temperature = profile.temperatureRange
        targetTemperatureLow = temperature.lowerBound
        targetTemperatureHigh = temperature.upperBound

        let humidity = profile.humidityRange
        targetHumidityLow = humidity.lowerBound
        targetHumidityHigh = humidity.upperBound
    }

    var phase: DryingPhase {
        get { DryingPhase(rawValue: phaseRaw) ?? .drying }
        set { phaseRaw = newValue.rawValue }
    }

    var profile: DryingProfile {
        get { DryingProfile(rawValue: profileRaw) ?? .hangDry }
        set {
            profileRaw = newValue.rawValue
            let temperature = newValue.temperatureRange
            targetTemperatureLow = temperature.lowerBound
            targetTemperatureHigh = temperature.upperBound
            let humidity = newValue.humidityRange
            targetHumidityLow = humidity.lowerBound
            targetHumidityHigh = humidity.upperBound
        }
    }

    var burpMode: BurpMode {
        get { BurpMode(rawValue: burpModeRaw) ?? .progressive }
        set { burpModeRaw = newValue.rawValue }
    }

    var targetHumidityRange: ClosedRange<Double> {
        targetHumidityLow...max(targetHumidityLow, targetHumidityHigh)
    }

    var targetTemperatureRange: ClosedRange<Double> {
        targetTemperatureLow...max(targetTemperatureLow, targetTemperatureHigh)
    }

    var curingHumidityRange: ClosedRange<Double> {
        curingHumidityLow...max(curingHumidityLow, curingHumidityHigh)
    }

    var sortedChecks: [DryingCheck] {
        checks.sorted { $0.date < $1.date }
    }

    var latestCheck: DryingCheck? { sortedChecks.last }

    var sortedBurps: [CureBurp] {
        burps.sorted { $0.date > $1.date }
    }

    var isActive: Bool { phase == .drying || phase == .curing }
}
