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
        case .seed: return "Seed"
        case .clone: return "Clone"
        case .veg: return "Vegetative"
        case .flower: return "Flowering"
        case .harvest: return "Harvest"
        case .cure: return "Curing"
        case .storage: return "Storage"
        }
    }

    var shortTitle: String {
        switch self {
        case .seed: return "Seed"
        case .clone: return "Clone"
        case .veg: return "Veg"
        case .flower: return "Flower"
        case .harvest: return "Harvest"
        case .cure: return "Cure"
        case .storage: return "Storage"
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
            return "Keep the medium moist but not soaked, stay near 22–26 °C, and keep the light gentle. Watch for the first true leaves before you move on."
        case .clone:
            return "Keep humidity high and light low while roots form. Move the plant to veg once you see new white roots and fresh growth."
        case .veg:
            return "This is where shape is set. Watch node spacing, keep the light schedule steady, and log feeds so you can compare cycles."
        case .flower:
            return "Photoperiod is everything now. Keep the dark period completely dark, watch humidity, and check trichomes as the weeks go by."
        case .harvest:
            return "Weigh wet, hang or rack the plant in a cool dark space, and keep the drying room near 18–21 °C and 58–62% humidity."
        case .cure:
            return "Burp the jars, keep humidity near 58–62%, and let the flower cure for two to four weeks before you judge it."
        case .storage:
            return "Stored flower is finished plant material. Keep it labeled, check it periodically, and record what you keep, use or destroy."
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
        case .seed: return "Seed"
        case .clone: return "Clone"
        case .cutting: return "Cutting"
        }
    }

    var subtitle: String {
        switch self {
        case .seed: return "Started from a seed"
        case .clone: return "Rooted clone from a mother"
        case .cutting: return "Unrooted cutting"
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
        case .retained: return "Retained"
        case .consumedAtHome: return "Consumed at home"
        case .destroyed: return "Destroyed"
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
        case .retained: return "Kept in storage at home."
        case .consumedAtHome: return "Used at home by the cultivator."
        case .destroyed: return "Destroyed and not kept."
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
        case .tent: return "Tent"
        case .closet: return "Closet"
        case .room: return "Room"
        case .greenhouse: return "Greenhouse"
        case .outdoor: return "Outdoor"
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
        case .singleFamily: return "Single-family home"
        case .multiUnit: return "Multi-unit building"
        case .rental: return "Rental"
        }
    }

    var subtitle: String {
        switch self {
        case .singleFamily: return "A house you control, including the yard"
        case .multiUnit: return "Apartment, condo or shared building"
        case .rental: return "You rent the property you grow in"
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
        case .beginner: return "First grow"
        case .intermediate: return "A few cycles"
        case .experienced: return "Experienced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return "Plain-language guidance and gentle prompts"
        case .intermediate: return "Guidance when you need it, detail when you want it"
        case .experienced: return "Compact interface, raw numbers, fewer prompts"
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
        case .note: return "Note"
        case .observation: return "Observation"
        case .photo: return "Photo"
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
        case .healthy: return "Healthy growth"
        case .yellowing: return "Yellowing leaves"
        case .drooping: return "Drooping"
        case .pests: return "Pests"
        case .moldRisk: return "Mold risk"
        case .nutrients: return "Nutrient issue"
        case .stretching: return "Stretching"
        case .other: return "Other"
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
        case .indica: return "Indica"
        case .sativa: return "Sativa"
        case .hybrid: return "Hybrid"
        }
    }

    var subtitle: String {
        switch self {
        case .indica: return "Compact and broad-leafed, usually a shorter flowering window"
        case .sativa: return "Taller and stretchier, often a longer flowering window"
        case .hybrid: return "A cross of both, with the ratio left to the breeder"
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
        case .topping: return "Topping"
        case .lowStressTraining: return "Low-stress training"
        case .defoliation: return "Defoliation"
        case .supercropping: return "Supercropping"
        case .scrogTuck: return "SCROG tuck"
        }
    }

    var subtitle: String {
        switch self {
        case .topping:
            return "Remove the growing tip to split the canopy."
        case .lowStressTraining:
            return "Bend and tie branches to level the canopy."
        case .defoliation:
            return "Remove leaves to open airflow and light."
        case .supercropping:
            return "Soften and bend a stem to slow that shoot."
        case .scrogTuck:
            return "Weave a growing shoot under the net."
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
