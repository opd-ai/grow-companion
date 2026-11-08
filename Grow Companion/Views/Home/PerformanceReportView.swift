//
//  PerformanceReportView.swift
//  Grow Companion
//
//  Read-only performance report from existing grow records.
//

import SwiftUI
import SwiftData
import Charts

struct PerformanceReportView: View {
    @Query(sort: \Plant.harvestedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var endDate = Date()

    private var finishedPlants: [Plant] {
        plants.filter { plant in
            guard let harvestedAt = plant.harvestedAt else { return false }
            return harvestedAt >= startDate && harvestedAt <= endDate
        }
    }

    private var measuredYields: [Double] { finishedPlants.compactMap(\.dryWeightGrams) }
    private var gramsPerWatt: [Double] {
        finishedPlants.compactMap { plant in
            guard let dry = plant.dryWeightGrams, let watts = plant.room?.lightWatts, watts > 0 else { return nil }
            return HarvestLog.gramsPerWatt(dryGrams: dry, watts: watts)
        }
    }
    private var floweringDays: [Double] { finishedPlants.compactMap { StrainInsights.floweringDays(for: $0).map(Double.init) } }
    private var outOfRangeReadings: [EnvironmentReading] {
        rooms.flatMap(\.environmentReadings).filter { $0.date >= startDate && $0.date <= endDate && $0.isAnyOutOfRange }
    }
    private var totalReadings: Int {
        rooms.flatMap(\.environmentReadings).filter { $0.date >= startDate && $0.date <= endDate }.count
    }
    private var feedCount: Int { rooms.flatMap(\.feedEvents).filter { $0.date >= startDate && $0.date <= endDate }.count }
    private var trainingCount: Int { plants.flatMap(\.trainingSessions).filter { $0.date >= startDate && $0.date <= endDate }.count }
    private var scoutingCount: Int { rooms.flatMap(\.scoutingChecks).filter { $0.date >= startDate && $0.date <= endDate }.count + plants.flatMap(\.scoutingChecks).filter { $0.date >= startDate && $0.date <= endDate }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                dateSelector
                summaryCard
                environmentTrendCard
                careCard
                breakdownCard
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Performance")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Your records, compared carefully.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    private var dateSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Date range", subtitle: "Only records inside this range are included")
            HStack {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
            }
            .font(Theme.sans(13))
            .tint(Theme.primary)
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14, radius: 16)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader("Harvest outcomes", subtitle: "Finished plants with recorded values")
            HStack(spacing: 10) {
                metric("Dry yield", measuredYields.isEmpty ? "Not recorded" : Format.weight(measuredYields.reduce(0, +), unit: .metric), detail: limited(measuredYields.count))
                metric("Grams / watt", gramsPerWatt.isEmpty ? "Not recorded" : String(format: "%.2f", gramsPerWatt.reduce(0, +) / Double(gramsPerWatt.count)), detail: limited(gramsPerWatt.count))
            }
            HStack(spacing: 10) {
                metric("Flowering", floweringDays.isEmpty ? "Not recorded" : Format.dayCount(Int((floweringDays.reduce(0, +) / Double(floweringDays.count)).rounded())), detail: limited(floweringDays.count))
                metric("Harvests", finishedPlants.isEmpty ? "No data" : "\(finishedPlants.count)", detail: finishedPlants.count < 3 ? "Limited data" : "Recorded")
            }
            Text("Missing measurements remain unreported. The report never estimates yield, wattage or flowering duration.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private func metric(_ title: String, _ value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Theme.tertiaryInk)
            Text(value)
                .font(Theme.serif(20))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(Theme.sans(10))
                .foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var environmentTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Environment signals", subtitle: "Out-of-range readings by recorded week")
            if outOfRangeReadings.isEmpty {
                Text(totalReadings == 0 ? "No environment readings in this range." : "No out-of-range readings in this range.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceSunken))
            } else {
                Chart(weeklyOutOfRange) { point in
                    BarMark(
                        x: .value("Week", point.date, unit: .weekOfYear),
                        y: .value("Out of range", point.count)
                    )
                    .foregroundStyle(Theme.amber)
                }
                .frame(height: 160)
                .chartYAxis { AxisMarks(position: .leading, values: .automatic) }
                .accessibilityLabel("Out-of-range environment readings over time")
                Text("\(outOfRangeReadings.count) of \(totalReadings) recorded readings were outside their room target.")
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.amber)

                ChartTableDisclosure(
                    table: ChartTables.weeklyCounts(
                        weeklyOutOfRange.map { WeeklyCount(date: $0.date, count: $0.count) },
                        summary: "\(outOfRangeReadings.count) of \(totalReadings) recorded readings were outside their room target, week by week."
                    )
                )
            }
        }
        .growCard()
    }

    private var careCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Care records", subtitle: "Activity recorded in the selected range")
            InfoRow(label: "Feeds and waterings", value: "\(feedCount)")
            InfoRow(label: "Training sessions", value: "\(trainingCount)")
            InfoRow(label: "Scouting checks", value: "\(scoutingCount)")
            if feedCount == 0 && trainingCount == 0 && scoutingCount == 0 {
                Text("No care records in this range.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
            }
        }
        .growCard(fill: Theme.surfaceSunken)
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Recorded by room and strain", subtitle: "No comparisons are shown where data is missing")
            if finishedPlants.isEmpty {
                Text("No finished plants in this range.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                ForEach(finishedPlants) { plant in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: plant.stage.systemImage)
                            .foregroundStyle(Theme.primary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plant.displayName)
                                .font(Theme.sans(13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text("\(plant.room?.name ?? "Room not recorded") · \(plant.displayStrain)")
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.secondaryInk)
                            Text(detail(for: plant))
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.tertiaryInk)
                        }
                        Spacer(minLength: 4)
                    }
                    if plant.id != finishedPlants.last?.id { Divider().overlay(Theme.hairline) }
                }
            }
        }
        .growCard(padding: 16)
    }

    private var weeklyOutOfRange: [PerformanceWeek] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: outOfRangeReadings) { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date }
        return grouped.map { PerformanceWeek(date: $0.key, count: $0.value.count) }.sorted { $0.date < $1.date }
    }

    private func limited(_ count: Int) -> String { count < 3 ? "Limited data" : "\(count) records" }

    private func detail(for plant: Plant) -> String {
        var values: [String] = []
        if let dry = plant.dryWeightGrams { values.append(Format.weight(dry, unit: .metric)) } else { values.append("Yield not recorded") }
        if let days = StrainInsights.floweringDays(for: plant) { values.append("\(days) days flowering") } else { values.append("Flowering duration not recorded") }
        return values.joined(separator: " · ")
    }
}

private struct PerformanceWeek: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}
