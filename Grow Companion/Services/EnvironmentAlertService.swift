//
//  EnvironmentAlertService.swift
//  Grow Companion
//
//  Detects sustained temperature and humidity excursions.
//
//  A run of out-of-range readings only counts as sustained when the readings
//  are close enough together to evidence a continuous excursion. A single
//  reading, or two out-of-range readings separated by a gap longer than the
//  threshold, never raises an alert.
//

import Foundation
import SwiftData

/// A sustained out-of-range stretch: its start, the reading that confirmed it,
/// and how long the record shows it lasted.
struct SustainedExcursion: Identifiable, Hashable {
    let metric: EnvironmentMetric
    let startedAt: Date
    let detectedAt: Date
    let value: Double
    let target: ClosedRange<Double>
    let lastedMinutes: Int

    var id: String { "\(metric.rawValue)-\(startedAt.timeIntervalSince1970)" }
    var isAbove: Bool { value > target.upperBound }
}

enum EnvironmentAlertService {
    /// The sustained excursions in these readings, oldest first.
    ///
    /// Readings are ordered by date. An in-range reading ends the current run.
    /// A gap longer than the required duration also ends it, because the record
    /// then holds no evidence that the room stayed out of range.
    static func excursions(
        in readings: [EnvironmentReading],
        metric: EnvironmentMetric,
        target: ClosedRange<Double>,
        requiredMinutes: Int
    ) -> [SustainedExcursion] {
        let required = max(1, requiredMinutes)
        let maximumGap = TimeInterval(required * 60)

        let points: [(date: Date, value: Double)] = readings
            .compactMap { reading in
                guard let value = metric.value(from: reading) else { return nil }
                return (reading.date, value)
            }
            .sorted { $0.date < $1.date }

        var excursions: [SustainedExcursion] = []
        var run: [(date: Date, value: Double)] = []

        func flush() {
            defer { run.removeAll() }
            guard let first = run.first, let last = run.last else { return }
            let lasted = Int(last.date.timeIntervalSince(first.date) / 60)
            guard lasted >= required else { return }
            excursions.append(
                SustainedExcursion(
                    metric: metric,
                    startedAt: first.date,
                    detectedAt: last.date,
                    value: last.value,
                    target: target,
                    lastedMinutes: lasted
                )
            )
        }

        for point in points {
            guard !target.contains(point.value) else {
                flush()
                continue
            }
            if let lastInRun = run.last,
               point.date.timeIntervalSince(lastInRun.date) > maximumGap {
                flush()
            }
            run.append(point)
        }
        flush()

        return excursions
    }

    /// Records an alert for the newest sustained excursion in the reading just
    /// saved, once per excursion, and schedules its notification with a
    /// suggested action. Quiet hours are respected unless the grower marks the
    /// readings category as critical.
    static func evaluate(reading: EnvironmentReading, room: Room, context: ModelContext) {
        var readings = room.environmentReadings
        if !readings.contains(where: { $0.date == reading.date }) {
            readings.append(reading)
        }

        for metric in [EnvironmentMetric.temperature, .humidity] {
            guard let target = metric.target(in: room) else { continue }

            let sustained = excursions(
                in: readings,
                metric: metric,
                target: target,
                requiredMinutes: room.sustainedAlertMinutes
            )
            guard let latest = sustained.last else { continue }
            // Only the reading just saved can confirm an excursion, so an older
            // excursion is never re-reported when a later reading is added.
            guard latest.detectedAt == reading.date else { continue }
            guard !room.environmentAlerts.contains(where: { alert in
                alert.metricRaw == metric.rawValue && alert.detectedAt >= latest.startedAt
            }) else { continue }

            let alert = EnvironmentAlert(
                metric: metric,
                value: latest.value,
                target: target,
                detectedAt: latest.detectedAt,
                room: room
            )
            context.insert(alert)
            CareNotifications.schedule(
                alert,
                room: room,
                suggestedAction: suggestedAction(for: metric, value: latest.value, target: target)
            )
        }
    }

    /// A short, non-diagnostic suggestion that matches the direction of the
    /// excursion. It never names a product or a treatment.
    static func suggestedAction(
        for metric: EnvironmentMetric,
        value: Double,
        target: ClosedRange<Double>
    ) -> String {
        switch metric {
        case .temperature:
            return value > target.upperBound
                ? String(localized: "Temperature is above the target. Ventilate the room or raise the light, and check that the fan is running.")
                : String(localized: "Temperature is below the target. Reduce cooling or add gentle heat, and keep the room out of cold drafts.")
        case .humidity:
            return value > target.upperBound
                ? String(localized: "Humidity is above the target. Increase airflow and check for wet spots; high humidity raises mould risk.")
                : String(localized: "Humidity is below the target. Raise it gradually and keep the room steady.")
        case .light:
            return String(localized: "Light is outside the target. Check the fixture height and its schedule.")
        }
    }
}
