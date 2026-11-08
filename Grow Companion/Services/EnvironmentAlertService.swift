//
//  EnvironmentAlertService.swift
//  Grow Companion
//
//  Detects sustained temperature and humidity excursions.
//

import Foundation
import SwiftData

enum EnvironmentAlertService {
    static func evaluate(reading: EnvironmentReading, room: Room, context: ModelContext) {
        for metric in [EnvironmentMetric.temperature, .humidity] {
            guard let value = metric.value(from: reading), let target = metric.target(in: room), !target.contains(value) else { continue }

            let priorReadings = room.environmentReadings
                .filter { $0.date < reading.date }
                .sorted { $0.date > $1.date }
            var sustainedStart = reading.date
            for prior in priorReadings {
                guard let priorValue = metric.value(from: prior) else { continue }
                if target.contains(priorValue) { break }
                sustainedStart = prior.date
            }

            let minutes = Calendar.current.dateComponents([.minute], from: sustainedStart, to: reading.date).minute ?? 0
            guard minutes >= max(1, room.sustainedAlertMinutes) else { continue }
            guard !room.environmentAlerts.contains(where: { $0.metricRaw == metric.rawValue && $0.detectedAt >= sustainedStart }) else { continue }

            let alert = EnvironmentAlert(metric: metric, value: value, target: target, detectedAt: reading.date, room: room)
            context.insert(alert)
            CareNotifications.schedule(alert, room: room)
        }
    }
}
