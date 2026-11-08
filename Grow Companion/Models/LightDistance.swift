//
//  LightDistance.swift
//  Grow Companion
//

import Foundation

enum LightFixtureType: String, CaseIterable, Codable, Identifiable {
    case led
    case hps
    case cmh
    case fluorescent
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .led: return "LED"
        case .hps: return "HPS"
        case .cmh: return "CMH"
        case .fluorescent: return String(localized: "Fluorescent")
        case .other: return String(localized: "Other")
        }
    }

    var targetRangeMeters: ClosedRange<Double>? {
        switch self {
        case .led: return 0.30...0.60
        case .hps: return 0.45...0.75
        case .cmh: return 0.45...0.75
        case .fluorescent: return 0.15...0.30
        case .other: return nil
        }
    }

    var guidanceSource: String {
        switch self {
        case .led: return String(localized: "General LED manufacturer guidance; verify your fixture manual")
        case .hps: return String(localized: "General HPS manufacturer guidance; verify your fixture manual")
        case .cmh: return String(localized: "General CMH manufacturer guidance; verify your fixture manual")
        case .fluorescent: return String(localized: "General fluorescent fixture guidance; verify your fixture manual")
        case .other: return String(localized: "No default target; use the fixture manual")
        }
    }
}

enum LightDistanceSource: String, Codable {
    case lidar
    case manual
}
