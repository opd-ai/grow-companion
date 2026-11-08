//
//  EnvironmentChartView.swift
//  Grow Companion
//
//  A line chart for one metric with the stage's target range drawn on it,
//  out-of-range points marked, and a data table alternative for VoiceOver.
//

import SwiftUI
import Charts

struct EnvironmentChartView: View {
    let readings: [EnvironmentReading]
    let metric: EnvironmentMetric
    let targetRange: ClosedRange<Double>?
    let unit: UnitSystem

    private var recentReadings: [EnvironmentReading] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) else { return readings }
        return readings.filter { $0.date >= cutoff }
    }

    private var points: [EnvironmentPoint] {
        recentReadings.compactMap { reading -> EnvironmentPoint? in
            guard let value = metric.value(from: reading) else { return nil }
            let outOfRange = targetRange.map { !$0.contains(value) } ?? false
            return EnvironmentPoint(
                id: String(describing: reading.persistentModelID),
                date: reading.date,
                value: value,
                isOutOfRange: outOfRange
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var outOfRangeCount: Int {
        points.filter { $0.isOutOfRange }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if points.isEmpty {
                Text("No \(metric.title.lowercased()) readings in the last 7 days.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )
            } else {
                Chart {
                    if let targetRange {
                        RuleMark(y: .value("Target minimum", targetRange.lowerBound))
                            .foregroundStyle(Theme.sage)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        RuleMark(y: .value("Target maximum", targetRange.upperBound))
                            .foregroundStyle(Theme.sage)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }

                    ForEach(points) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value(metric.title, point.value)
                        )
                        .foregroundStyle(Theme.primary.opacity(0.65))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Time", point.date),
                            y: .value(metric.title, point.value)
                        )
                        .foregroundStyle(point.isOutOfRange ? Theme.danger : Theme.primary)
                        .symbolSize(34)
                    }
                }
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)

                if let targetRange {
                    Text("Dashed lines mark the \(metric.displayTarget(targetRange, unit: unit)) target for \(metric.title.lowercased()).")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if targetRange != nil {
                    Text(outOfRangeCount == 0
                         ? "Every reading is inside the target range."
                         : "\(outOfRangeCount) of \(points.count) readings are outside the target range.")
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(outOfRangeCount == 0 ? Theme.primary : Theme.amber)
                }

                ChartTableDisclosure(
                    table: ChartTables.environment(
                        points: points,
                        metric: metric,
                        unit: unit,
                        summary: accessibilitySummary
                    )
                )
            }
        }
    }

    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else {
            return String(localized: "\(metric.title) chart with no readings.")
        }
        let values = points.map { $0.value }
        let minimum = values.min() ?? first.value
        let maximum = values.max() ?? last.value
        var summary = "\(metric.title) chart, \(points.count) readings over the last 7 days, from \(metric.display(first.value, unit: unit)) to \(metric.display(last.value, unit: unit)), lowest \(metric.display(minimum, unit: unit)), highest \(metric.display(maximum, unit: unit))."
        if targetRange != nil {
            summary += " \(outOfRangeCount) readings outside the target range."
        }
        summary += " A data table lists every reading."
        return summary
    }
}
