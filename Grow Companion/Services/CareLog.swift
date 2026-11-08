//
//  CareLog.swift
//  Grow Companion
//
//  Targets, drift checks, reminder timing and the 30-day raw / hourly-average
//  rule for environment readings.
//

import Foundation
import SwiftData

// MARK: - Metrics and kinds

enum EnvironmentMetric: String, CaseIterable, Identifiable {
    case temperature
    case humidity
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .temperature: return String(localized: "Temperature")
        case .humidity: return String(localized: "Humidity")
        case .light: return String(localized: "Light")
        }
    }

    var systemImage: String {
        switch self {
        case .temperature: return "thermometer.medium"
        case .humidity: return "drop"
        case .light: return "sun.max"
        }
    }

    func value(from reading: EnvironmentReading) -> Double? {
        switch self {
        case .temperature: return reading.temperatureC
        case .humidity: return reading.humidityPercent
        case .light: return reading.lightPPFD
        }
    }

    func target(in room: Room) -> ClosedRange<Double>? {
        switch self {
        case .temperature: return room.targetTemperatureRange
        case .humidity: return room.targetHumidityRange
        case .light: return nil
        }
    }

    func display(_ value: Double, unit: UnitSystem) -> String {
        switch self {
        case .temperature: return Format.temperature(value, unit: unit)
        case .humidity: return String(format: "%.0f%%", value)
        case .light: return String(format: "%.0f PPFD", value)
        }
    }

    func displayTarget(_ range: ClosedRange<Double>, unit: UnitSystem) -> String {
        switch self {
        case .temperature: return Format.temperatureRange(range, unit: unit)
        case .humidity: return String(format: "%.0f–%.0f%%", range.lowerBound, range.upperBound)
        case .light: return String(localized: "No target set")
        }
    }
}

enum FeedKind: String, CaseIterable, Identifiable {
    case water
    case feed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: return String(localized: "Watering")
        case .feed: return String(localized: "Feed")
        }
    }

    var actionTitle: String {
        switch self {
        case .water: return String(localized: "Log watering")
        case .feed: return String(localized: "Log feed")
        }
    }

    var systemImage: String {
        switch self {
        case .water: return "drop"
        case .feed: return "flask"
        }
    }
}

enum CalibrationMeter: String, CaseIterable, Identifiable {
    case phMeter
    case ecProbe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phMeter: return String(localized: "pH meter")
        case .ecProbe: return String(localized: "EC probe")
        }
    }

    var systemImage: String {
        switch self {
        case .phMeter: return "paintpalette"
        case .ecProbe: return "bolt.horizontal"
        }
    }

    var defaultIntervalDays: Int { 30 }
}

enum CareReminderKind: String, CaseIterable, Identifiable {
    case water
    case feed
    case reading
    case calibration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: return String(localized: "Water")
        case .feed: return String(localized: "Feed")
        case .reading: return String(localized: "Log a reading")
        case .calibration: return String(localized: "Calibrate meters")
        }
    }

    var systemImage: String {
        switch self {
        case .water: return "drop"
        case .feed: return "flask"
        case .reading: return "thermometer.medium"
        case .calibration: return "gauge.with.dots.needle.50percent"
        }
    }
}

struct FeedDriftItem: Identifiable {
    let id: String
    let label: String
    let message: String
}

struct EnvironmentPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    let isOutOfRange: Bool
}

// MARK: - Care log

enum CareLog {
    static let rawRetentionDays = 30

    // MARK: Targets

    static func nextDue(after date: Date, intervalDays: Int, timeOfDayMinutes: Int) -> Date {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: date)

        if intervalDays > 0 {
            day = calendar.date(byAdding: .day, value: intervalDays, to: day) ?? day
        }

        var candidate = calendar.date(
            bySettingHour: timeOfDayMinutes / 60,
            minute: timeOfDayMinutes % 60,
            second: 0,
            of: day
        ) ?? day

        if candidate <= date {
            candidate = calendar.date(byAdding: .day, value: max(1, intervalDays), to: candidate) ?? candidate
        }

        return candidate
    }

    static func complete(_ reminder: CareReminder) {
        reminder.lastCompletedAt = Date()
        reminder.nextDueDate = nextDue(
            after: Date(),
            intervalDays: reminder.repeatDays,
            timeOfDayMinutes: reminder.timeOfDayMinutes
        )
        CareNotifications.schedule(reminder)
    }

    // MARK: Feed drift

    static func drift(for event: FeedEvent, room: Room) -> [FeedDriftItem] {
        drift(
            room: room,
            phIn: event.phIn,
            ecIn: event.ecIn,
            phRunoff: event.phRunoff,
            ecRunoff: event.ecRunoff
        )
    }

    static func drift(
        room: Room,
        phIn: Double?,
        ecIn: Double?,
        phRunoff: Double?,
        ecRunoff: Double?
    ) -> [FeedDriftItem] {
        drift(
            targetPH: room.feedTargetPH,
            targetEC: room.feedTargetEC,
            phIn: phIn,
            ecIn: ecIn,
            phRunoff: phRunoff,
            ecRunoff: ecRunoff
        )
    }

    /// Drift against explicit targets, so a week's feed schedule can stand in
    /// for the room's reservoir targets.
    static func drift(
        targetPH: Double?,
        targetEC: Double?,
        phIn: Double?,
        ecIn: Double?,
        phRunoff: Double?,
        ecRunoff: Double?
    ) -> [FeedDriftItem] {
        var items: [FeedDriftItem] = []

        if let target = targetPH {
            if let phIn {
                appendPHDrift(id: "phIn", label: "pH in", value: phIn, target: target, into: &items)
            }
            if let phRunoff {
                appendPHDrift(id: "phRunoff", label: "Runoff pH", value: phRunoff, target: target, into: &items)
            }
        }

        if let target = targetEC {
            if let ecIn {
                appendECDrift(id: "ecIn", label: "EC in", value: ecIn, target: target, into: &items)
            }
            if let ecRunoff {
                appendECDrift(id: "ecRunoff", label: "Runoff EC", value: ecRunoff, target: target, into: &items)
            }
        }

        return items
    }

    private static func appendPHDrift(
        id: String,
        label: String,
        value: Double,
        target: Double,
        into items: inout [FeedDriftItem]
    ) {
        let delta = value - target
        guard abs(delta) > 0.3 else { return }
        let direction = delta > 0 ? "above" : "below"
        items.append(
            FeedDriftItem(
                id: id,
                label: label,
                message: "\(String(format: "%.1f", value)) is \(String(format: "%.1f", abs(delta))) \(direction) your \(String(format: "%.1f", target)) target"
            )
        )
    }

    private static func appendECDrift(
        id: String,
        label: String,
        value: Double,
        target: Double,
        into items: inout [FeedDriftItem]
    ) {
        let delta = value - target
        guard abs(delta) > 0.2 else { return }
        let direction = delta > 0 ? "above" : "below"
        items.append(
            FeedDriftItem(
                id: id,
                label: label,
                message: "\(String(format: "%.2f", value)) is \(String(format: "%.2f", abs(delta))) \(direction) your \(String(format: "%.2f", target)) target"
            )
        )
    }

    // MARK: Downsampling

    /// Turns raw readings older than 30 days into one hourly average per room
    /// and hour, then deletes the raw rows.
    static func compact(readings: [EnvironmentReading], context: ModelContext) {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -rawRetentionDays, to: Date()) else { return }

        let old = readings.filter { !$0.isHourlyAverage && $0.date < cutoff }
        guard !old.isEmpty else { return }

        struct BucketKey: Hashable {
            let roomID: String
            let hour: Date
        }

        var buckets: [BucketKey: [EnvironmentReading]] = [:]
        for reading in old {
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: reading.date)
            let hour = calendar.date(from: components) ?? reading.date
            let roomID = reading.room.map { String(describing: $0.persistentModelID) } ?? "none"
            let key = BucketKey(roomID: roomID, hour: hour)
            buckets[key, default: []].append(reading)
        }

        for (key, group) in buckets {
            let aggregate = EnvironmentReading(
                date: key.hour,
                temperatureC: average(group.map { $0.temperatureC }),
                humidityPercent: average(group.map { $0.humidityPercent }),
                lightPPFD: average(group.map { $0.lightPPFD }),
                isHourlyAverage: true,
                sampleCount: group.count,
                room: group.first?.room
            )
            context.insert(aggregate)
            for original in group {
                context.delete(original)
            }
        }

        try? context.save()
    }

    static func average(_ values: [Double?]) -> Double? {
        let present = values.compactMap { $0 }
        guard !present.isEmpty else { return nil }
        return present.reduce(0, +) / Double(present.count)
    }
}

// MARK: - Stage targets

extension PlantStage {
    /// Typical target range for the stage, used only to compare readings.
    var targetTemperatureC: ClosedRange<Double>? {
        switch self {
        case .seed: return 21...27
        case .clone: return 20...26
        case .veg: return 20...28
        case .flower: return 18...26
        case .harvest: return 18...21
        case .cure: return 18...22
        case .storage: return 15...21
        }
    }

    var targetHumidityPercent: ClosedRange<Double>? {
        switch self {
        case .seed: return 65...80
        case .clone: return 70...85
        case .veg: return 50...70
        case .flower: return 40...55
        case .harvest: return 55...62
        case .cure: return 58...62
        case .storage: return 55...62
        }
    }
}

// MARK: - Room conveniences

extension Room {
    /// The most advanced stage present in the room, used for target ranges.
    var dominantStage: PlantStage? {
        let order: [PlantStage] = [.seed, .clone, .veg, .flower, .harvest, .cure, .storage]
        let indices = plants.compactMap { order.firstIndex(of: $0.stage) }
        guard let highest = indices.max() else { return nil }
        return order[highest]
    }

    var targetTemperatureRange: ClosedRange<Double>? {
        (dominantStage ?? .veg).targetTemperatureC
    }

    var targetHumidityRange: ClosedRange<Double>? {
        (dominantStage ?? .veg).targetHumidityPercent
    }

    var sortedEnvironmentReadings: [EnvironmentReading] {
        environmentReadings.sorted { $0.date < $1.date }
    }

    var latestEnvironmentReading: EnvironmentReading? {
        sortedEnvironmentReadings.last
    }

    var sortedFeedEvents: [FeedEvent] {
        feedEvents.sorted { $0.date > $1.date }
    }

    var sortedCalibrationEvents: [CalibrationEvent] {
        calibrationEvents.sorted { $0.date > $1.date }
    }

    var nextCalibrationDue: Date? {
        sortedCalibrationEvents.compactMap { $0.nextDueDate }.min()
    }
}
