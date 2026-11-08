//
//  LightSchedule.swift
//  Grow Companion
//
//  Photoperiod maths: presets, hours of light, the next on or off time and a
//  live countdown. Times are stored as minutes from midnight so they survive
//  daylight saving changes without moving.
//

import Foundation

enum LightPreset: String, CaseIterable, Identifiable {
    case eighteenSix = "18/6"
    case twelveTwelve = "12/12"
    case twentyFour = "20/4"
    case custom = "Custom"

    var id: String { rawValue }

    var title: String {
        self == .custom ? String(localized: "Custom") : rawValue
    }

    var hoursOfLight: Int? {
        switch self {
        case .eighteenSix: return 18
        case .twelveTwelve: return 12
        case .twentyFour: return 20
        case .custom: return nil
        }
    }

    var subtitle: String {
        switch self {
        case .eighteenSix: return String(localized: "Vegetative growth")
        case .twelveTwelve: return String(localized: "Flowering")
        case .twentyFour: return String(localized: "Fast vegetative growth")
        case .custom: return String(localized: "Your own on and off times")
        }
    }

    static func matching(hours: Double) -> LightPreset {
        for preset in [LightPreset.eighteenSix, .twelveTwelve, .twentyFour] {
            if let value = preset.hoursOfLight, abs(Double(value) - hours) < 0.01 {
                return preset
            }
        }
        return .custom
    }
}

struct LightSwitch {
    let date: Date
    let isTurningOn: Bool
}

enum LightSchedule {
    static let dayMinutes = 24 * 60

    static func hours(on: Int, off: Int) -> Double {
        let difference = ((off - on) % dayMinutes + dayMinutes) % dayMinutes
        return Double(difference == 0 ? dayMinutes : difference) / 60.0
    }

    static func summary(on: Int, off: Int) -> String {
        let light = hours(on: on, off: off)
        let dark = 24 - light
        return String(localized: "\(formatHours(light)) on · \(formatHours(dark)) off")
    }

    static func formatHours(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 {
            return String(localized: "\(Int(value.rounded())) h")
        }
        return String(format: "%.1f h", value)
    }

    static func timeLabel(_ minutes: Int) -> String {
        let normalized = ((minutes % dayMinutes) + dayMinutes) % dayMinutes
        let hour = normalized / 60
        let minute = normalized % 60
        let date = Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
        return labelFormatter.string(from: date)
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour * 60 + minute
    }

    static func date(forMinutes minutes: Int, on day: Date = Date(), calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: minutes, to: startOfDay) ?? day
    }

    static func isOn(on: Int, off: Int, at now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let current = minutes(from: now, calendar: calendar)
        if on == off { return true }
        if on < off {
            return current >= on && current < off
        }
        return current >= on || current < off
    }

    static func nextSwitch(on: Int, off: Int, from now: Date = Date(), calendar: Calendar = .current) -> LightSwitch? {
        let startOfDay = calendar.startOfDay(for: now)
        var candidates: [LightSwitch] = []

        for dayOffset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else { continue }
            if let onDate = calendar.date(byAdding: .minute, value: on, to: day) {
                candidates.append(LightSwitch(date: onDate, isTurningOn: true))
            }
            if let offDate = calendar.date(byAdding: .minute, value: off, to: day) {
                candidates.append(LightSwitch(date: offDate, isTurningOn: false))
            }
        }

        return candidates
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .first
    }

    static func countdown(from now: Date, to target: Date) -> String {
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(localized: "\(hours)h \(minutes)m \(remainingSeconds)s")
        }
        if minutes > 0 {
            return String(localized: "\(minutes)m \(remainingSeconds)s")
        }
        return String(localized: "\(remainingSeconds)s")
    }

    static func countdownCompact(from now: Date, to target: Date) -> String {
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 { return String(localized: "\(hours)h \(minutes)m") }
        return String(localized: "\(minutes)m")
    }

    private static let labelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
