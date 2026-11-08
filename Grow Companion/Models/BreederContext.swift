//
//  BreederContext.swift
//  Grow Companion
//
//  Read-only reference context for breeder profiles and lineage disclosure.
//

import Foundation

enum LineageStatus: String, CaseIterable, Codable, Identifiable {
    case documented
    case disputed
    case missing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documented: return String(localized: "Documented")
        case .disputed: return String(localized: "Disputed")
        case .missing: return String(localized: "Not documented")
        }
    }

    var systemImage: String {
        switch self {
        case .documented: return "checkmark.seal"
        case .disputed: return "exclamationmark.triangle"
        case .missing: return "questionmark"
        }
    }
}

struct BreederProfileReference: Hashable {
    let name: String
    let summary: String
    let source: String
}

struct StrainReferenceContext: Hashable {
    let breederProfile: BreederProfileReference?
    let parentLines: String?
    let claimedYield: String?
    let source: String?
}
