//
//  EducationLibrary.swift
//  Grow Companion
//
//  Bundled, offline-first learning content. The lessons are guidance, not
//  legal, medical or product recommendations. Every lesson carries the date
//  its copy was reviewed, and the lessons about the rules name the rule pack
//  they were written against.
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

    /// The rule pack a lesson about the rules was written against, so the
    /// grower can see which version its wording belongs to.
    let rulePackCitation: String?

    /// The review date in the locale the app is reading, not a fixed pattern.
    var reviewedLabel: String { Format.shortDate(reviewedOn) }

    var citesRulePack: Bool { rulePackCitation != nil }
}

enum EducationLibrary {
    /// Reviewed with the rule pack, so the content review and the rule review
    /// stay on one schedule.
    static let reviewDate = RulePack.verifiedDate ?? fallbackReviewDate

    /// Shown on the lesson that describes the rules.
    static var rulePackCitation: String {
        String(
            localized: "Written against rule pack \(RulePack.version), verified \(RulePack.displayDate(RulePack.verifiedOn))."
        )
    }

    static let lessons: [EducationLesson] = [
        EducationLesson(
            id: "fundamentals-room-routine",
            topic: .fundamentals,
            title: String(localized: "A repeatable room routine"),
            summary: String(localized: "Small, consistent checks make it easier to notice when a room is drifting. Look, measure, record and review rather than relying on memory."),
            reviewedOn: reviewDate,
            checklist: [
                String(localized: "Check the canopy and leaves"),
                String(localized: "Review temperature and humidity"),
                String(localized: "Confirm the light schedule"),
                String(localized: "Log anything that changed")
            ],
            destination: .room,
            rulePackCitation: nil
        ),
        EducationLesson(
            id: "fundamentals-stage-changes",
            topic: .fundamentals,
            title: String(localized: "Use stages as a shared language"),
            summary: String(localized: "A stage is a practical label for what the plant needs now. Record changes when they happen so later comparisons have a clear starting point."),
            reviewedOn: reviewDate,
            checklist: [
                String(localized: "Choose the current stage"),
                String(localized: "Record the date of a change"),
                String(localized: "Use stage targets as guidance"),
                String(localized: "Add context in the plant note")
            ],
            destination: .plant,
            rulePackCitation: nil
        ),
        EducationLesson(
            id: "pests-scouting",
            topic: .pestManagement,
            title: String(localized: "Scout before you treat"),
            summary: String(localized: "Regular observation helps separate a single unusual leaf from a pattern. Record what you see and avoid turning a guess into a treatment recommendation."),
            reviewedOn: reviewDate,
            checklist: [
                String(localized: "Inspect new growth and leaf undersides"),
                String(localized: "Look for mold risk and pests"),
                String(localized: "Record findings with a date"),
                String(localized: "Photograph useful evidence")
            ],
            destination: .plant,
            rulePackCitation: nil
        ),
        EducationLesson(
            id: "pests-room-signals",
            topic: .pestManagement,
            title: String(localized: "Read the room as well as the plant"),
            summary: String(localized: "Air movement, moisture and temperature affect how quickly problems can develop. Room records give plant observations useful context."),
            reviewedOn: reviewDate,
            checklist: [
                String(localized: "Review recent room readings"),
                String(localized: "Check airflow around the canopy"),
                String(localized: "Compare readings with the stage target"),
                String(localized: "Log a room scouting check")
            ],
            destination: .room,
            rulePackCitation: nil
        ),
        EducationLesson(
            id: "curing-slow-finish",
            topic: .curing,
            title: String(localized: "The finish is a slow process"),
            summary: String(localized: "Drying and curing need steady conditions and regular checks. Use measured readings and record changes instead of relying on a fixed calendar alone."),
            reviewedOn: reviewDate,
            checklist: [
                String(localized: "Confirm the drying or curing target"),
                String(localized: "Take a check reading"),
                String(localized: "Watch for mold risk"),
                String(localized: "Record the next action")
            ],
            destination: .plant,
            rulePackCitation: nil
        ),
        EducationLesson(
            id: "compliance-know-your-rule",
            topic: .compliance,
            title: String(localized: "Know which rule you selected"),
            summary: String(localized: "The app summarizes the jurisdiction you confirmed, but rules can change and local requirements may differ. Review the citation and verify current law before acting."),
            reviewedOn: reviewDate,
            checklist: [
                String(localized: "Review your selected jurisdiction"),
                String(localized: "Read the plain-language limit"),
                String(localized: "Open the official citation"),
                String(localized: "Verify current local requirements")
            ],
            destination: .compliance,
            rulePackCitation: rulePackCitation
        )
    ]

    static func lessons(for topic: EducationTopic) -> [EducationLesson] {
        lessons.filter { $0.topic == topic }
    }

    static func lesson(withID id: String) -> EducationLesson? {
        lessons.first { $0.id == id }
    }

    /// How many lessons of a topic the grower has read.
    static func readCount(for topic: EducationTopic, in progress: EducationReadingProgress) -> Int {
        progress.count(in: lessons(for: topic))
    }

    private static let fallbackReviewDate: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 5
        components.day = 15
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 1_747_267_200)
    }()
}
