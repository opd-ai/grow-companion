//
//  GardenTimeline.swift
//  Grow Companion
//
//  Merges every timestamped garden record into one read-only, date-ordered
//  list. Nothing here writes to the store: the timeline is a reading surface.
//

import Foundation
import SwiftData

enum GardenEventKind: String, CaseIterable, Identifiable {
    case stage
    case journal
    case feed
    case reading
    case calibration
    case lightSchedule
    case training
    case treatment
    case scouting
    case dryingCheck
    case cureBurp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stage: return "Stage"
        case .journal: return "Journal"
        case .feed: return "Feed"
        case .reading: return "Reading"
        case .calibration: return "Calibration"
        case .lightSchedule: return "Light schedule"
        case .training: return "Training"
        case .treatment: return "Treatment"
        case .scouting: return "Scouting"
        case .dryingCheck: return "Drying check"
        case .cureBurp: return "Burping"
        }
    }

    var systemImage: String {
        switch self {
        case .stage: return "arrow.triangle.2.circlepath"
        case .journal: return "book.closed"
        case .feed: return "drop"
        case .reading: return "thermometer.medium"
        case .calibration: return "gauge.with.dots.needle.50percent"
        case .lightSchedule: return "sun.max"
        case .training: return "scissors"
        case .treatment: return "cross.case"
        case .scouting: return "eye"
        case .dryingCheck: return "wind"
        case .cureBurp: return "hourglass"
        }
    }
}

struct GardenEvent: Identifiable {
    let id: String
    let date: Date
    let kind: GardenEventKind
    let title: String
    let detail: String?
    let plant: Plant?
    let room: Room?
    let journalEntry: JournalEntry?

    var roomName: String? { room?.name ?? plant?.room?.name }
    var plantName: String? { plant?.displayName }

    var hasDestination: Bool {
        journalEntry != nil || plant != nil || room != nil
    }
}

/// The records the timeline reads. Kept as one value so the merge is a pure
/// function and the view can feed it live queries.
struct GardenTimelineSources {
    var stageEvents: [StageEvent] = []
    var journal: [JournalEntry] = []
    var feeds: [FeedEvent] = []
    var readings: [EnvironmentReading] = []
    var calibrations: [CalibrationEvent] = []
    var lightEvents: [LightScheduleEvent] = []
    var training: [TrainingSession] = []
    var treatments: [Treatment] = []
    var scouting: [ScoutingCheck] = []
    var dryingChecks: [DryingCheck] = []
    var cureBurps: [CureBurp] = []
}

/// Local filter state. A value type that never touches the store.
struct GardenTimelineFilter: Equatable {
    var roomID: PersistentIdentifier?
    var plantID: PersistentIdentifier?
    var kinds: Set<GardenEventKind> = Set(GardenEventKind.allCases)

    func matches(_ event: GardenEvent) -> Bool {
        guard kinds.contains(event.kind) else { return false }

        if let plantID {
            guard event.plant?.persistentModelID == plantID else { return false }
        }

        if let roomID {
            let matchesRoom = event.room?.persistentModelID == roomID
                || event.plant?.room?.persistentModelID == roomID
            guard matchesRoom else { return false }
        }

        return true
    }
}

enum GardenTimelineService {
    /// Every timestamped event type the roadmap lists, exactly once each, in
    /// descending date order.
    static func events(
        from sources: GardenTimelineSources,
        unit: UnitSystem = .metric
    ) -> [GardenEvent] {
        var events: [GardenEvent] = []

        events.append(contentsOf: sources.stageEvents.map { event in
            let plant = event.plant
            var detail = event.note
            if event.isBackfilled {
                detail = detail.isEmpty ? "Backfilled" : "Backfilled · \(detail)"
            }
            return GardenEvent(
                id: identifier(kind: .stage, model: event),
                date: event.date,
                kind: .stage,
                title: "Moved to \(event.stage.title)",
                detail: detail.isEmpty ? nil : detail,
                plant: plant,
                room: plant?.room,
                journalEntry: nil
            )
        })

        events.append(contentsOf: sources.journal.map { entry in
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = text.isEmpty ? entry.tag?.title : text
            return GardenEvent(
                id: identifier(kind: .journal, model: entry),
                date: entry.createdAt,
                kind: .journal,
                title: entry.kind.title,
                detail: detail,
                plant: entry.plant,
                room: entry.room,
                journalEntry: entry
            )
        })

        events.append(contentsOf: sources.feeds.map { event in
            let pieces = [
                event.volumeLiters.map { Format.volume($0, unit: unit) },
                event.phIn.map { "pH \(number($0, digits: 1)) in" },
                event.ecIn.map { "EC \(number($0, digits: 2)) in" },
                event.phRunoff.map { "pH \(number($0, digits: 1)) runoff" },
                event.ecRunoff.map { "EC \(number($0, digits: 2)) runoff" }
            ].compactMap { $0 }
            let detail = pieces.isEmpty ? event.note : pieces.joined(separator: " · ")
            return GardenEvent(
                id: identifier(kind: .feed, model: event),
                date: event.date,
                kind: .feed,
                title: event.kind == .water ? "Watered" : "Fed",
                detail: detail.isEmpty ? nil : detail,
                plant: nil,
                room: event.room,
                journalEntry: nil
            )
        })

        events.append(contentsOf: sources.readings.map { reading in
            let pieces = [
                reading.temperatureC.map { Format.temperature($0, unit: unit) },
                reading.humidityPercent.map { "\(number($0, digits: 0))% humidity" },
                reading.lightPPFD.map { "\(number($0, digits: 0)) PPFD" }
            ].compactMap { $0 }
            let detail = pieces.joined(separator: " · ")
            return GardenEvent(
                id: identifier(kind: .reading, model: reading),
                date: reading.date,
                kind: .reading,
                title: reading.isHourlyAverage ? "Hourly environment average" : "Environment reading",
                detail: detail.isEmpty ? nil : detail,
                plant: nil,
                room: reading.room,
                journalEntry: nil
            )
        })

        events.append(contentsOf: sources.calibrations.map { event in
            let pieces = [
                event.reading.map { "Reading \(number($0, digits: 2))" },
                event.note.isEmpty ? nil : event.note
            ].compactMap { $0 }
            return GardenEvent(
                id: identifier(kind: .calibration, model: event),
                date: event.date,
                kind: .calibration,
                title: "Calibrated \(event.meter.title.lowercased())",
                detail: pieces.isEmpty ? nil : pieces.joined(separator: " · "),
                plant: nil,
                room: event.room,
                journalEntry: nil
            )
        })

        events.append(contentsOf: sources.lightEvents.map { event in
            GardenEvent(
                id: identifier(kind: .lightSchedule, model: event),
                date: event.date,
                kind: .lightSchedule,
                title: "Light schedule changed",
                detail: "\(event.previousSummary) → \(event.newSummary)",
                plant: nil,
                room: event.room,
                journalEntry: nil
            )
        })

        events.append(contentsOf: sources.training.map { session in
            let pieces = [
                session.nodesAffected.map { "\($0) nodes" },
                session.note.isEmpty ? nil : session.note
            ].compactMap { $0 }
            return GardenEvent(
                id: identifier(kind: .training, model: session),
                date: session.date,
                kind: .training,
                title: session.method.title,
                detail: pieces.isEmpty ? nil : pieces.joined(separator: " · "),
                plant: session.plant,
                room: session.plant?.room,
                journalEntry: nil
            )
        })

        events.append(contentsOf: sources.treatments.map { treatment in
            let pieces = [
                treatment.dose.isEmpty ? nil : treatment.dose,
                treatment.withdrawalEndDate.map { "Withdrawal ends \(Format.shortDate($0))" },
                treatment.note.isEmpty ? nil : treatment.note
            ].compactMap { $0 }
            return GardenEvent(
                id: identifier(kind: .treatment, model: treatment),
                date: treatment.date,
                kind: .treatment,
                title: treatment.productName.isEmpty ? "Treatment" : treatment.productName,
                detail: pieces.isEmpty ? nil : pieces.joined(separator: " · "),
                plant: treatment.plant,
                room: treatment.room ?? treatment.plant?.room,
                journalEntry: nil
            )
        })

        events.append(contentsOf: sources.scouting.map { check in
            let pieces = [
                check.findings.isEmpty ? nil : check.findings.map(\.title).joined(separator: ", "),
                check.note.isEmpty ? nil : check.note
            ].compactMap { $0 }
            return GardenEvent(
                id: identifier(kind: .scouting, model: check),
                date: check.date,
                kind: .scouting,
                title: "Scouting check",
                detail: pieces.isEmpty ? nil : pieces.joined(separator: " · "),
                plant: check.plant,
                room: check.room ?? check.plant?.room,
                journalEntry: nil
            )
        })

        events.append(contentsOf: sources.dryingChecks.map { check in
            let plant = check.session?.plant
            let pieces = [
                check.humidityPercent.map { "\(number($0, digits: 0))% humidity" },
                check.temperatureC.map { Format.temperature($0, unit: unit) },
                check.stemSnap?.title,
                check.note.isEmpty ? nil : check.note
            ].compactMap { $0 }
            return GardenEvent(
                id: identifier(kind: .dryingCheck, model: check),
                date: check.date,
                kind: .dryingCheck,
                title: "Drying check",
                detail: pieces.isEmpty ? nil : pieces.joined(separator: " · "),
                plant: plant,
                room: plant?.room,
                journalEntry: nil
            )
        })

        events.append(contentsOf: sources.cureBurps.map { burp in
            let plant = burp.session?.plant
            return GardenEvent(
                id: identifier(kind: .cureBurp, model: burp),
                date: burp.date,
                kind: .cureBurp,
                title: "Burped",
                detail: burp.note.isEmpty ? nil : burp.note,
                plant: plant,
                room: plant?.room,
                journalEntry: nil
            )
        })

        return events.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id < rhs.id
        }
    }

    private static func identifier(kind: GardenEventKind, model: any PersistentModel) -> String {
        "\(kind.rawValue)-\(String(describing: model.persistentModelID))"
    }

    private static func number(_ value: Double, digits: Int) -> String {
        String(
            format: "%.\(digits)f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}
