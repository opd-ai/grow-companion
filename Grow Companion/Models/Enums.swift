//
//  Enums.swift
//  Grow Companion
//
//  Shared value types used by the SwiftData models and the rule engine.
//

import Foundation

// MARK: - Plant lifecycle

enum PlantStage: String, CaseIterable, Codable, Hashable, Identifiable {
    case seed
    case clone
    case veg
    case flower
    case harvest
    case cure
    case storage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seed: return String(localized: "Seed")
        case .clone: return String(localized: "Clone")
        case .veg: return String(localized: "Vegetative")
        case .flower: return String(localized: "Flowering")
        case .harvest: return String(localized: "Harvest")
        case .cure: return String(localized: "Curing")
        case .storage: return String(localized: "Storage")
        }
    }

    var shortTitle: String {
        switch self {
        case .seed: return String(localized: "Seed")
        case .clone: return String(localized: "Clone")
        case .veg: return String(localized: "Veg")
        case .flower: return String(localized: "Flower")
        case .harvest: return String(localized: "Harvest")
        case .cure: return String(localized: "Cure")
        case .storage: return String(localized: "Storage")
        }
    }

    var systemImage: String {
        switch self {
        case .seed: return "circle.dashed"
        case .clone: return "scissors"
        case .veg: return "leaf"
        case .flower: return "camera.macro"
        case .harvest: return "arrow.down.circle"
        case .cure: return "hourglass"
        case .storage: return "archivebox"
        }
    }

    /// The next stage in the normal progression. Seed and clone both lead to veg.
    var next: PlantStage? {
        switch self {
        case .seed, .clone: return .veg
        case .veg: return .flower
        case .flower: return .harvest
        case .harvest: return .cure
        case .cure: return .storage
        case .storage: return nil
        }
    }

    /// Typical time spent in the stage, used only to nudge the user when a
    /// stage has clearly overrun. Never presented as a deadline.
    var expectedDays: Int? {
        switch self {
        case .seed: return 10
        case .clone: return 14
        case .veg: return 35
        case .flower: return 63
        case .harvest: return 10
        case .cure: return 21
        case .storage: return nil
        }
    }

    var guidance: String {
        switch self {
        case .seed:
            return String(localized: "Keep the medium moist but not soaked, stay near 22–26 °C, and keep the light gentle. Watch for the first true leaves before you move on.")
        case .clone:
            return String(localized: "Keep humidity high and light low while roots form. Move the plant to veg once you see new white roots and fresh growth.")
        case .veg:
            return String(localized: "This is where shape is set. Watch node spacing, keep the light schedule steady, and log feeds so you can compare cycles.")
        case .flower:
            return String(localized: "Photoperiod is everything now. Keep the dark period completely dark, watch humidity, and check trichomes as the weeks go by.")
        case .harvest:
            return String(localized: "Weigh wet, hang or rack the plant in a cool dark space, and keep the drying room near 18–21 °C and 58–62% humidity.")
        case .cure:
            return String(localized: "Burp the jars, keep humidity near 58–62%, and let the flower cure for two to four weeks before you judge it.")
        case .storage:
            return String(localized: "Stored flower is finished plant material. Keep it labeled, check it periodically, and record what you keep, use or destroy.")
        }
    }
}

enum PlantOrigin: String, CaseIterable, Codable, Hashable, Identifiable {
    case seed
    case clone
    case cutting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seed: return String(localized: "Seed")
        case .clone: return String(localized: "Clone")
        case .cutting: return String(localized: "Cutting")
        }
    }

    var subtitle: String {
        switch self {
        case .seed: return String(localized: "Started from a seed")
        case .clone: return String(localized: "Rooted clone from a mother")
        case .cutting: return String(localized: "Unrooted cutting")
        }
    }

    var systemImage: String {
        switch self {
        case .seed: return "circle.dashed"
        case .clone: return "scissors"
        case .cutting: return "leaf"
        }
    }

    /// Seeds start in the seed stage, clones and cuttings start in clone.
    var startingStage: PlantStage {
        switch self {
        case .seed: return .seed
        case .clone, .cutting: return .clone
        }
    }
}

enum HarvestDisposition: String, CaseIterable, Codable, Hashable, Identifiable {
    case retained
    case consumedAtHome
    case destroyed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .retained: return String(localized: "Retained")
        case .consumedAtHome: return String(localized: "Consumed at home")
        case .destroyed: return String(localized: "Destroyed")
        }
    }

    var systemImage: String {
        switch self {
        case .retained: return "archivebox"
        case .consumedAtHome: return "house"
        case .destroyed: return "trash"
        }
    }

    var explanation: String {
        switch self {
        case .retained: return String(localized: "Kept in storage at home.")
        case .consumedAtHome: return String(localized: "Used at home by the cultivator.")
        case .destroyed: return String(localized: "Destroyed and not kept.")
        }
    }
}

// MARK: - Rooms

enum RoomType: String, CaseIterable, Codable, Hashable, Identifiable {
    case tent
    case closet
    case room
    case greenhouse
    case outdoor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tent: return String(localized: "Tent")
        case .closet: return String(localized: "Closet")
        case .room: return String(localized: "Room")
        case .greenhouse: return String(localized: "Greenhouse")
        case .outdoor: return String(localized: "Outdoor")
        }
    }

    var systemImage: String {
        switch self {
        case .tent: return "tent"
        case .closet: return "door.left.hand.closed"
        case .room: return "square.split.bottomrightquarter"
        case .greenhouse: return "house.lodge"
        case .outdoor: return "sun.max"
        }
    }

    var defaultIsIndoor: Bool {
        self != .outdoor && self != .greenhouse
    }
}

// MARK: - Grow profile

enum ResidenceType: String, CaseIterable, Codable, Hashable, Identifiable {
    case singleFamily
    case multiUnit
    case rental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleFamily: return String(localized: "Single-family home")
        case .multiUnit: return String(localized: "Multi-unit building")
        case .rental: return String(localized: "Rental")
        }
    }

    var subtitle: String {
        switch self {
        case .singleFamily: return String(localized: "A house you control, including the yard")
        case .multiUnit: return String(localized: "Apartment, condo or shared building")
        case .rental: return String(localized: "You rent the property you grow in")
        }
    }

    var systemImage: String {
        switch self {
        case .singleFamily: return "house"
        case .multiUnit: return "building.2"
        case .rental: return "key"
        }
    }
}

enum ExperienceLevel: String, CaseIterable, Codable, Hashable, Identifiable {
    case beginner
    case intermediate
    case experienced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return String(localized: "First grow")
        case .intermediate: return String(localized: "A few cycles")
        case .experienced: return String(localized: "Experienced")
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return String(localized: "Plain-language guidance and gentle prompts")
        case .intermediate: return String(localized: "Guidance when you need it, detail when you want it")
        case .experienced: return String(localized: "Compact interface, raw numbers, fewer prompts")
        }
    }

    var systemImage: String {
        switch self {
        case .beginner: return "sparkles"
        case .intermediate: return "chart.line.uptrend.xyaxis"
        case .experienced: return "dial.high"
        }
    }

    /// Beginners see explanations, experienced growers see compact summaries.
    var showsDetailedGuidance: Bool {
        self != .experienced
    }
}

// MARK: - Journal

enum JournalKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case note
    case observation
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .note: return String(localized: "Note")
        case .observation: return String(localized: "Observation")
        case .photo: return String(localized: "Photo")
        }
    }

    var systemImage: String {
        switch self {
        case .note: return "text.alignleft"
        case .observation: return "eye"
        case .photo: return "photo"
        }
    }
}

enum ObservationTag: String, CaseIterable, Codable, Hashable, Identifiable {
    case healthy
    case yellowing
    case drooping
    case pests
    case moldRisk
    case nutrients
    case stretching
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthy: return String(localized: "Healthy growth")
        case .yellowing: return String(localized: "Yellowing leaves")
        case .drooping: return String(localized: "Drooping")
        case .pests: return String(localized: "Pests")
        case .moldRisk: return String(localized: "Mold risk")
        case .nutrients: return String(localized: "Nutrient issue")
        case .stretching: return String(localized: "Stretching")
        case .other: return String(localized: "Other")
        }
    }

    var systemImage: String {
        switch self {
        case .healthy: return "checkmark.circle"
        case .yellowing: return "leaf"
        case .drooping: return "arrow.down.right"
        case .pests: return "ant"
        case .moldRisk: return "cloud.fog"
        case .nutrients: return "drop"
        case .stretching: return "arrow.up.right"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Strains

enum StrainType: String, CaseIterable, Codable, Hashable, Identifiable {
    case indica
    case sativa
    case hybrid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indica: return String(localized: "Indica")
        case .sativa: return String(localized: "Sativa")
        case .hybrid: return String(localized: "Hybrid")
        }
    }

    var subtitle: String {
        switch self {
        case .indica: return String(localized: "Compact and broad-leafed, usually a shorter flowering window")
        case .sativa: return String(localized: "Taller and stretchier, often a longer flowering window")
        case .hybrid: return String(localized: "A cross of both, with the ratio left to the breeder")
        }
    }

    var systemImage: String {
        switch self {
        case .indica: return "moon"
        case .sativa: return "sun.max"
        case .hybrid: return "leaf"
        }
    }
}

// MARK: - Training

enum TrainingMethod: String, CaseIterable, Codable, Hashable, Identifiable {
    case topping
    case lowStressTraining
    case defoliation
    case supercropping
    case scrogTuck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topping: return String(localized: "Topping")
        case .lowStressTraining: return String(localized: "Low-stress training")
        case .defoliation: return String(localized: "Defoliation")
        case .supercropping: return String(localized: "Supercropping")
        case .scrogTuck: return String(localized: "SCROG tuck")
        }
    }

    var subtitle: String {
        switch self {
        case .topping:
            return String(localized: "Remove the growing tip to split the canopy.")
        case .lowStressTraining:
            return String(localized: "Bend and tie branches to level the canopy.")
        case .defoliation:
            return String(localized: "Remove leaves to open airflow and light.")
        case .supercropping:
            return String(localized: "Soften and bend a stem to slow that shoot.")
        case .scrogTuck:
            return String(localized: "Weave a growing shoot under the net.")
        }
    }

    var systemImage: String {
        switch self {
        case .topping: return "scissors"
        case .lowStressTraining: return "arrow.triangle.branch"
        case .defoliation: return "leaf"
        case .supercropping: return "arrow.up.and.down"
        case .scrogTuck: return "square.grid.3x3"
        }
    }
}
