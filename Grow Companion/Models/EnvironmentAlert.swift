//
//  EnvironmentAlert.swift
//  Grow Companion
//
//  A sustained out-of-range temperature or humidity alert.
//

import Foundation
import SwiftData

@Model
final class EnvironmentAlert {
    var metricRaw: String = EnvironmentMetric.temperature.rawValue
    var value: Double = 0
    var targetLow: Double = 0
    var targetHigh: Double = 0
    var detectedAt: Date = Date()
    var acknowledgedAt: Date?
    var notificationIdentifier: String = UUID().uuidString
    var room: Room?

    init(metric: EnvironmentMetric, value: Double, target: ClosedRange<Double>, detectedAt: Date = Date(), room: Room? = nil) {
        self.metricRaw = metric.rawValue
        self.value = value
        self.targetLow = target.lowerBound
        self.targetHigh = target.upperBound
        self.detectedAt = detectedAt
        self.room = room
    }

    var metric: EnvironmentMetric { EnvironmentMetric(rawValue: metricRaw) ?? .temperature }
    var target: ClosedRange<Double> { targetLow...max(targetLow, targetHigh) }
    var isAcknowledged: Bool { acknowledgedAt != nil }
}
