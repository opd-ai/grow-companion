//
//  EducationLibrary.swift
//  Grow Companion
//
//  Bundled, offline-first learning content. The lessons are guidance, not
//  legal, medical or product recommendations.
//

import Foundation

enum EducationTopic: String, CaseIterable, Identifiable {
    case fundamentals
    case pestManagement
    case curing
    case compliance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fundamentals: return String(localized: "Fundamentals")
        case .pestManagement: return String(localized: "Pest checks")
        case .curing: return String(localized: "Drying and curing")
        case .compliance: return String(localized: "Compliance")
        }
    }

    var subtitle: String {
        switch self {
        case .fundamentals: return String(localized: "Build a steady room routine")
        case .pestManagement: return String(localized: "Notice changes before they spread")
        case .curing: return String(localized: "Protect the finish after harvest")
        case .compliance: return String(localized: "Understand the rules you selected")
        }
    }

    var systemImage: String {
        switch self {
        case .fundamentals: return "leaf"
        case .pestManagement: return "magnifyingglass"
        case .curing: return "hourglass"
        case .compliance: return "checkmark.shield"
        }
    }
}

enum EducationApplyDestination: Hashable {
    case room
    case plant
    case compliance
}

struct EducationLesson: Identifiable, Hashable {
    let id: String
    let topic: EducationTopic
    let title: String
    let summary: String
    let reviewedOn: Date
    let checklist: [String]
    let destination: EducationApplyDestination

    var reviewedLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: reviewedOn)
    }
}

enum EducationLibrary {
    static let reviewDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15)) ?? Date()

    static let lessons: [EducationLesson] = [
        EducationLesson(
            id: "fundamentals-room-routine",
            topic: .fundamentals,
            title: "A repeatable room routine",
            summary: "Small, consistent checks make it easier to notice when a room is drifting. Look, measure, record and review rather than relying on memory.",
            reviewedOn: reviewDate,
            checklist: ["Check the canopy and leaves", "Review temperature and humidity", "Confirm the light schedule", "Log anything that changed"],
            destination: .room
        ),
        EducationLesson(
            id: "fundamentals-stage-changes",
            topic: .fundamentals,
            title: "Use stages as a shared language",
            summary: "A stage is a practical label for what the plant needs now. Record changes when they happen so later comparisons have a clear starting point.",
            reviewedOn: reviewDate,
            checklist: ["Choose the current stage", "Record the date of a change", "Use stage targets as guidance", "Add context in the plant note"],
            destination: .plant
        ),
        EducationLesson(
            id: "pests-scouting",
            topic: .pestManagement,
            title: "Scout before you treat",
            summary: "Regular observation helps separate a single unusual leaf from a pattern. Record what you see and avoid turning a guess into a treatment recommendation.",
            reviewedOn: reviewDate,
            checklist: ["Inspect new growth and leaf undersides", "Look for mold risk and pests", "Record findings with a date", "Photograph useful evidence"],
            destination: .plant
        ),
        EducationLesson(
            id: "pests-room-signals",
            topic: .pestManagement,
            title: "Read the room as well as the plant",
            summary: "Air movement, moisture and temperature affect how quickly problems can develop. Room records give plant observations useful context.",
            reviewedOn: reviewDate,
            checklist: ["Review recent room readings", "Check airflow around the canopy", "Compare readings with the stage target", "Log a room scouting check"],
            destination: .room
        ),
        EducationLesson(
            id: "curing-slow-finish",
            topic: .curing,
            title: "The finish is a slow process",
            summary: "Drying and curing need steady conditions and regular checks. Use measured readings and record changes instead of relying on a fixed calendar alone.",
            reviewedOn: reviewDate,
            checklist: ["Confirm the drying or curing target", "Take a check reading", "Watch for mold risk", "Record the next action"],
            destination: .plant
        ),
        EducationLesson(
            id: "compliance-know-your-rule",
            topic: .compliance,
            title: "Know which rule you selected",
            summary: "The app summarizes the jurisdiction you confirmed, but rules can change and local requirements may differ. Review the citation and verify current law before acting.",
            reviewedOn: reviewDate,
            checklist: ["Review your selected jurisdiction", "Read the plain-language limit", "Open the official citation", "Verify current local requirements"],
            destination: .compliance
        )
    ]

    static func lessons(for topic: EducationTopic) -> [EducationLesson] {
        lessons.filter { $0.topic == topic }
    }
}
