//
//  GrowCalendar.swift
//  Grow Companion
//
//  One month view of everything the grow has a date for: care reminders,
//  stage windows, harvest forecast windows and drying or curing checks. The
//  only write is an explicit reminder move, which re-schedules one
//  notification and cancels the old one.
//

import Foundation
import SwiftData

enum GrowCalendarKind: String, CaseIterable, Identifiable {
    case reminder
    case stageWindow
    case harvestWindow
    case dryingCheck
    case cureCheck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reminder: return "Reminder"
        case .stageWindow: return "Stage window"
        case .harvestWindow: return "Harvest window"
        case .dryingCheck: return "Drying check"
        case .cureCheck: return "Curing check"
        }
    }

    var systemImage: String {
        switch self {
        case .reminder: return "bell"
        case .stageWindow: return "arrow.triangle.2.circlepath"
        case .harvestWindow: return "scissors"
        case .dryingCheck: return "wind"
        case .cureCheck: return "hourglass"
        }
    }
}

/// One dated item on the calendar. Read-only apart from the reminder it
/// carries, which the move sheet can change.
struct GrowCalendarEntry: Identifiable {
    let id: String
    let date: Date
    let kind: GrowCalendarKind
    let title: String
    let detail: String?
    let roomName: String?
    let reminder: CareReminder?
    let plant: Plant?
}

/// The records a month is built from.
struct GrowCalendarSources {
    var reminders: [CareReminder] = []
    var plants: [Plant] = []
    var dryingSessions: [DryingSession] = []
}

/// The one side effect a reminder move has, kept behind a protocol so the
/// store write and the notification work can be tested separately.
protocol ReminderScheduling {
    func schedule(_ reminder: CareReminder)
    func cancel(_ reminder: CareReminder)
}

struct CareReminderScheduler: ReminderScheduling {
    func schedule(_ reminder: CareReminder) {
        CareNotifications.schedule(reminder)
    }

    func cancel(_ reminder: CareReminder) {
        CareNotifications.cancel(reminder)
    }
}

enum GrowCalendarError: LocalizedError {
    case inThePast
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .inThePast:
            return "A reminder cannot be moved to a day that has already passed."
        case .saveFailed(let detail):
            return "The reminder was not moved: \(detail)"
        }
    }
}

enum GrowCalendarService {
    /// Every dated item from every source, in date order.
    static func entries(
        from sources: GrowCalendarSources,
        now: Date = Date()
    ) -> [GrowCalendarEntry] {
        let calendar = Calendar.current
        var entries: [GrowCalendarEntry] = []

        for reminder in sources.reminders where reminder.isEnabled {
            entries.append(
                GrowCalendarEntry(
                    id: "reminder-\(reminder.notificationIdentifier)",
                    date: reminder.nextDueDate,
                    kind: .reminder,
                    title: reminder.displayTitle,
                    detail: "\(reminder.kind.title) · \(reminder.repeatLabel)",
                    roomName: reminder.room?.name,
                    reminder: reminder,
                    plant: nil
                )
            )
        }

        for plant in sources.plants where plant.isActive {
            guard let expectedDays = plant.stage.expectedDays else { continue }
            guard let ends = calendar.date(
                byAdding: .day,
                value: expectedDays,
                to: calendar.startOfDay(for: plant.stageStartedAt)
            ) else { continue }

            entries.append(
                GrowCalendarEntry(
                    id: "stage-\(String(describing: plant.persistentModelID))",
                    date: ends,
                    kind: .stageWindow,
                    title: "\(plant.displayName) · \(plant.stage.shortTitle) window",
                    detail: "A typical \(plant.stage.title.lowercased()) span is about \(Format.dayCount(expectedDays)). A nudge, not a deadline.",
                    roomName: plant.room?.name,
                    reminder: nil,
                    plant: plant
                )
            )
        }

        for forecast in HarvestCalendar.forecasts(for: sources.plants, now: now) {
            entries.append(
                GrowCalendarEntry(
                    id: "harvest-\(String(describing: forecast.plant.persistentModelID))",
                    date: forecast.mostLikelyDate,
                    kind: .harvestWindow,
                    title: "\(forecast.plant.displayName) · harvest window",
                    detail: "Most likely \(Format.shortDate(forecast.mostLikelyDate)), window \(Format.shortDate(forecast.windowStart))–\(Format.shortDate(forecast.windowEnd)). \(forecast.sourceText).",
                    roomName: forecast.plant.room?.name,
                    reminder: nil,
                    plant: forecast.plant
                )
            )
        }

        for session in sources.dryingSessions where session.isActive {
            let plantName = session.plant?.displayName ?? "Harvest"

            switch session.phase {
            case .drying:
                let last = session.latestCheck?.date ?? session.startedAt
                guard let next = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: last)
                ) else { continue }

                entries.append(
                    GrowCalendarEntry(
                        id: "drying-\(String(describing: session.persistentModelID))",
                        date: next,
                        kind: .dryingCheck,
                        title: "\(plantName) · drying check",
                        detail: "Target \(session.profile.title.lowercased()) profile: \(Format.temperatureRange(session.targetTemperatureRange, unit: .metric)), \(Int(session.targetHumidityRange.lowerBound))–\(Int(session.targetHumidityRange.upperBound))% RH.",
                        roomName: session.plant?.room?.name,
                        reminder: nil,
                        plant: session.plant
                    )
                )

            case .curing:
                let curingStart = session.curingStartedAt ?? session.startedAt
                let curingDay = max(
                    0,
                    calendar.dateComponents([.day], from: curingStart, to: now).day ?? 0
                )
                let interval = max(1, session.burpMode.intervalDays(curingDay: curingDay))
                let last = session.lastBurpedAt ?? curingStart
                guard let next = calendar.date(
                    byAdding: .day,
                    value: interval,
                    to: calendar.startOfDay(for: last)
                ) else { continue }

                entries.append(
                    GrowCalendarEntry(
                        id: "cure-\(String(describing: session.persistentModelID))",
                        date: next,
                        kind: .cureCheck,
                        title: "\(plantName) · burp the jars",
                        detail: "\(session.burpMode.title) schedule, \(Int(session.curingHumidityRange.lowerBound))–\(Int(session.curingHumidityRange.upperBound))% RH.",
                        roomName: session.plant?.room?.name,
                        reminder: nil,
                        plant: session.plant
                    )
                )

            case .finished:
                continue
            }
        }

        return entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.id < rhs.id
        }
    }

    /// Enabled reminders whose date has passed. They stay listed until the
    /// grower completes them, which moves the next date on.
    static func overdueReminders(
        from reminders: [CareReminder],
        now: Date = Date()
    ) -> [CareReminder] {
        reminders
            .filter { $0.isEnabled && $0.nextDueDate < now }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    /// Moves one reminder to another day, keeping its time of day. The store
    /// is written first, so a failed save leaves the existing notification and
    /// due date exactly as they were; on success the old request is cancelled
    /// and exactly one new one is scheduled.
    @discardableResult
    static func reschedule(
        reminder: CareReminder,
        to day: Date,
        schedulers: ReminderScheduling = CareReminderScheduler(),
        now: Date = Date(),
        in context: ModelContext
    ) throws -> Date {
        let calendar = Calendar.current
        let startOfNewDay = calendar.startOfDay(for: day)

        guard startOfNewDay >= calendar.startOfDay(for: now) else {
            throw GrowCalendarError.inThePast
        }

        let minutes = reminder.timeOfDayMinutes
        let newDueDate = calendar.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: startOfNewDay
        ) ?? startOfNewDay

        let previousDueDate = reminder.nextDueDate
        reminder.nextDueDate = newDueDate

        do {
            try context.save()
        } catch {
            reminder.nextDueDate = previousDueDate
            context.rollback()
            throw GrowCalendarError.saveFailed(error.localizedDescription)
        }

        schedulers.cancel(reminder)
        schedulers.schedule(reminder)

        return newDueDate
    }
}
