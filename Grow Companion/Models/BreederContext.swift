//
//  BreederContext.swift
//  Grow Companion
//
//  How a lineage is described. The reference material itself now lives in
//  `Models/BreederProfile.swift` and `Services/BreederLibrary.swift`.
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
