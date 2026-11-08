//
//  ChartTableTests.swift
//  Grow CompanionTests
//
//  Every chart and ring has a text equivalent; these are the row builders.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct ChartTableTests {
    @Test func environmentTableKeepsTheChartOrder() {
        let restore = Format.locale
        Format.locale = Locale(identifier: "en_US")
        defer { Format.locale = restore }

        let first = EnvironmentPoint(
            id: "a",
            date: Date(timeIntervalSince1970: 0),
            value: 20,
            isOutOfRange: false
        )
        let second = EnvironmentPoint(
            id: "b",
            date: Date(timeIntervalSince1970: 3600),
            value: 30,
            isOutOfRange: true
        )

        let table = ChartTables.environment(
            points: [first, second],
            metric: .temperature,
            unit: .metric,
            summary: "Two readings"
        )

        #expect(table.rows.count == 2)
        #expect(table.rows.map(\.id) == ["a", "b"])
        #expect(table.rows.first?.isFlagged == false)
        #expect(table.rows.last?.isFlagged == true)
        #expect(table.rows.last?.value.contains("°C") == true)
        #expect(table.summary == "Two readings")
        #expect(!table.isEmpty)
    }

    @Test func weeklyCountsListEveryRecordedWeek() {
        let restore = Format.locale
        Format.locale = Locale(identifier: "en_US")
        defer { Format.locale = restore }

        let week = Date(timeIntervalSince1970: 0)
        let table = ChartTables.weeklyCounts(
            [WeeklyCount(date: week, count: 3)],
            summary: "Three out of range"
        )

        #expect(table.rows.count == 1)
        #expect(table.rows.first?.value == "3 readings")
        #expect(table.rows.first?.label.hasPrefix("Week of") == true)
    }

    @Test func complianceTableMirrorsTheRing() throws {
        let restore = Format.locale
        Format.locale = Locale(identifier: "en_US")
        defer { Format.locale = restore }

        let rule = try #require(RulePack.rule(forStateCode: "CA"))
        let report = ComplianceEngine.report(
            plants: [],
            rooms: [],
            rule: rule,
            warningThreshold: 0.8
        )

        let table = ChartTables.compliance(report: report, unit: .metric)

        #expect(table.rows.count == 4)
        #expect(table.rows.map(\.label) == ["Plants counted", "Stored flower", "Canopy in use", "Overall"])
        #expect(table.rows.last?.value == report.overallLevel.title)
    }

    @Test func anEmptyTableIsNotOffered() {
        let table = ChartTables.environment(
            points: [],
            metric: .humidity,
            unit: .metric,
            summary: ""
        )
        #expect(table.isEmpty)
    }
}
