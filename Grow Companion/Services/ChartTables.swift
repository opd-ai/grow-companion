//
//  ChartTables.swift
//  Grow Companion
//
//  Pure builders for the text equivalent of each chart and ring. The views
//  draw the pictures; these functions list the same values as rows, so the
//  table can be tested without a screen.
//

import Foundation

/// One recorded week, for the out-of-range bar chart.
struct WeeklyCount: Identifiable, Equatable {
    let date: Date
    let count: Int

    var id: Date { date }
}

enum ChartTables {
    /// Readings oldest to newest, exactly as the chart draws them.
    static func environment(
        points: [EnvironmentPoint],
        metric: EnvironmentMetric,
        unit: UnitSystem,
        summary: String
    ) -> ChartTable {
        let rows = points.map { point in
            ChartTableRow(
                id: point.id,
                label: "\(Format.shortDate(point.date)) · \(Format.time(point.date))",
                value: metric.display(point.value, unit: unit),
                isFlagged: point.isOutOfRange
            )
        }

        return ChartTable(
            id: "environment-\(metric.rawValue)",
            title: "Data table",
            summary: summary,
            rows: rows
        )
    }

    /// The out-of-range bar chart's weekly counts.
    static func weeklyCounts(
        _ weeks: [WeeklyCount],
        summary: String
    ) -> ChartTable {
        let rows = weeks.map { week in
            ChartTableRow(
                id: "week-\(week.date.timeIntervalSince1970)",
                label: "Week of \(Format.shortDate(week.date))",
                value: week.count == 1 ? "1 reading" : "\(Format.number(Double(week.count), digits: 0)) readings",
                isFlagged: false
            )
        }

        return ChartTable(
            id: "out-of-range-weeks",
            title: "Data table",
            summary: summary,
            rows: rows
        )
    }

    /// The compliance ring's values, with the same levels it colours.
    static func compliance(
        report: ComplianceReport,
        unit: UnitSystem
    ) -> ChartTable {
        let plantValue = report.plantLimit.map {
            "\(Format.number(Double(report.countedPlants), digits: 0)) of \(Format.number(Double($0), digits: 0)) · \(report.plantLevel.title)"
        } ?? "\(Format.number(Double(report.countedPlants), digits: 0)) · \(report.plantLevel.title)"

        let possessionValue = "\(Format.weight(report.possessionGrams, unit: unit)) / \(Format.weightLimit(report.possessionLimitGrams, unit: unit)) · \(report.possessionLevel.title)"

        let canopyValue = "\(Format.area(report.canopySqM, unit: unit)) / \(Format.areaLimit(report.canopyLimitSqM, unit: unit)) · \(report.canopyLevel.title)"

        let rows = [
            ChartTableRow(
                id: "plants",
                label: "Plants counted",
                value: plantValue,
                isFlagged: report.plantLevel == .over
            ),
            ChartTableRow(
                id: "possession",
                label: "Stored flower",
                value: possessionValue,
                isFlagged: report.possessionLevel == .over
            ),
            ChartTableRow(
                id: "canopy",
                label: "Canopy in use",
                value: canopyValue,
                isFlagged: report.canopyLevel == .over
            ),
            ChartTableRow(
                id: "overall",
                label: "Overall",
                value: report.overallLevel.title,
                isFlagged: report.overallLevel == .over
            )
        ]

        return ChartTable(
            id: "compliance-values",
            title: "Values as a table",
            summary: "The same values the ring draws: \(report.statusTitle).",
            rows: rows
        )
    }
}
