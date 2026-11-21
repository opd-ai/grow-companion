//
//  StrainComparisonView.swift
//  Grow Companion
//
//  The cultivar comparison: the grower's own harvested cycles, side by side for
//  one measure at a time, with the number of cycles each average rests on. A
//  single cycle is labelled as one run, and a missing figure is left blank
//  rather than borrowed from a breeder's label.
//

import Charts
import SwiftData
import SwiftUI

struct StrainComparisonView: View {
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \Strain.name) private var strains: [Strain]
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var metric: CultivarMetric = .floweringDays

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var samples: [CultivarSample] {
        StrainComparison.samples(from: plants)
    }

    private var plotted: [CultivarSample] {
        StrainComparison.samples(samples, with: metric)
    }

    private var chartDomain: ClosedRange<Double> {
        let top = plotted.compactMap { metric.value(of: $0) }.max() ?? 1
        return 0...(max(top, 1) * 1.3)
    }

    private var chartHeight: CGFloat {
        let rows = CGFloat(max(plotted.count, 1))
        return min(max(rows * 46 + 36, 140), 460)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if samples.isEmpty {
                    emptyState
                } else {
                    measurePicker
                    chartCard
                    samplesCard
                    notesCard
                }
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Compare cultivars")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Your own finished cycles, side by side.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Measure

    private var measurePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Measure", subtitle: metric.subtitle)
            Picker("Measure", selection: $metric) {
                ForEach(CultivarMetric.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(Theme.primary)
        }
        .growCard(fill: Theme.surfaceSunken)
    }

    // MARK: Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                metric.title,
                subtitle: plotted.isEmpty
                    ? String(localized: "No finished cycle has a value for this measure yet.")
                    : String(localized: "Averages of your finished cycles.")
            )

            if plotted.isEmpty {
                Text("A plant needs a harvest recorded before it can be compared.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Chart(plotted) { sample in
                    BarMark(
                        x: .value(metric.title, metric.value(of: sample) ?? 0),
                        y: .value("Cultivar", sample.name)
                    )
                    .foregroundStyle(Theme.primary)
                    .cornerRadius(6)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(metric.display(metric.value(of: sample) ?? 0, unit: unit))
                            .font(Theme.sans(10, weight: .semibold))
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                .chartXScale(domain: chartDomain)
                .chartLegend(.hidden)
                .frame(height: chartHeight)
                .accessibilityLabel(String(localized: "\(metric.title) by cultivar"))
            }

            ChartTableDisclosure(
                table: ChartTables.cultivarComparison(
                    plotted,
                    metric: metric,
                    unit: unit,
                    summary: String(localized: "Your own finished cycles, averaged for each cultivar.")
                )
            )
        }
        .growCard()
    }

    // MARK: Rows

    private var samplesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                "Your cultivars",
                subtitle: String(localized: "Every cultivar with a finished cycle. Tap one for its history.")
            )

            VStack(spacing: 0) {
                ForEach(samples) { sample in
                    if let strain = strain(for: sample) {
                        NavigationLink {
                            StrainDetailView(strain: strain)
                        } label: {
                            row(sample)
                        }
                        .buttonStyle(.plain)
                    } else {
                        row(sample)
                    }

                    if sample.id != samples.last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }
        .growCard()
    }

    private func row(_ sample: CultivarSample) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(sample.name)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Text(StrainComparison.summary(for: sample))
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.trailing)
            }

            if let breeder = breederText(for: sample) {
                Text(breeder)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
            }

            HStack(spacing: 10) {
                valueTile(
                    CultivarMetric.floweringDays.title,
                    sample.floweringDays.map { Format.dayCount($0) } ?? "—"
                )
                valueTile(
                    CultivarMetric.dryYieldGrams.title,
                    sample.dryYieldGrams.map { Format.weight($0, unit: unit) } ?? "—"
                )
                valueTile(
                    CultivarMetric.rating.title,
                    sample.rating.map { Format.number($0, digits: 1) + " / 5" } ?? "—"
                )
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func valueTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Theme.tertiaryInk)
            Text(value)
                .font(Theme.sans(13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Notes and states

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Averages of finished cycles only. Missing values stay blank and the breeder's figure is never substituted.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if samples.contains(where: \.isSingleCycle) {
                Text("One cycle is a single run, not a pattern.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !StrainComparison.hasEnoughToCompare(samples) {
                Text("Only one cultivar has finished cycles. Add a second to see them side by side.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Nothing here is a prediction: every number is one of your own harvests, on this device.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(fill: Theme.surfaceSunken)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text("No completed cultivar to compare yet")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Assign a strain to a plant and finish a cycle: harvested, dried and weighed. This screen compares only your own records.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    // MARK: Helpers

    private func strain(for sample: CultivarSample) -> Strain? {
        guard let id = sample.strainID else { return nil }
        return strains.first { $0.persistentModelID == id }
    }

    private func breederText(for sample: CultivarSample) -> String? {
        guard let strain = strain(for: sample) else { return nil }
        return String(localized: "Breeder \(strain.floweringLabel)")
    }
}
