//
//  CycleComparisonView.swift
//  Grow Companion
//
//  Two finished harvests side by side: yield, efficiency, timing, feeding and
//  the grower's own verdict, with the difference in plain words.
//

import SwiftUI
import SwiftData

struct CycleComparisonView: View {
    let plant: Plant

    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var left: CycleSource?
    @State private var right: CycleSource?
    @State private var pickerSide: PickerSide?
    @State private var didSetDefault = false

    private enum PickerSide: String, Identifiable {
        case left
        case right

        var id: String { rawValue }
    }

    private struct MetricRow {
        let title: String
        let leftValue: Double?
        let rightValue: Double?
        let leftText: String
        let rightText: String
        let difference: String
        let tint: Color
        let direction: Int

        var maxValue: Double {
            max(leftValue ?? 0, rightValue ?? 0)
        }
    }

    private var unit: UnitSystem {
        UnitSystem(rawValue: unitRaw) ?? .metric
    }

    private var leftSnapshot: CycleSnapshot? {
        left.flatMap { CycleMetrics.snapshot(for: $0) }
    }

    private var rightSnapshot: CycleSnapshot? {
        right.flatMap { CycleMetrics.snapshot(for: $0) }
    }

    private var finishedPlants: [Plant] {
        plants
            .filter { CycleMetrics.isFinished($0) }
            .sorted {
                (CycleMetrics.harvestDate(for: $0) ?? .distantPast)
                    > (CycleMetrics.harvestDate(for: $1) ?? .distantPast)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                selectionRow

                if let leftSnapshot, let rightSnapshot {
                    heroCard(leftSnapshot, rightSnapshot)
                    metricsCard(leftSnapshot, rightSnapshot)
                    notesCard(leftSnapshot, rightSnapshot)
                    summaryCard(leftSnapshot, rightSnapshot)
                } else {
                    pickPrompt
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Compare cycles")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didSetDefault else { return }
            didSetDefault = true
            if left == nil { left = .plant(plant) }
            if right == nil { right = defaultRightSource() }
        }
        .sheet(item: $pickerSide) { side in
            CyclePickerSheet(
                title: side == .left ? "First cycle" : "Second cycle",
                options: pickerOptions(for: side)
            ) { source in
                if side == .left {
                    left = source
                } else {
                    right = source
                }
            }
        }
    }

    // MARK: Header and selection

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Compare cycles")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Two harvests, one honest look")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectionRow: some View {
        HStack(spacing: 8) {
            selectionChip(.left, snapshot: leftSnapshot)

            Button {
                let current = left
                left = right
                right = current
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.surfaceSunken))
            }
            .buttonStyle(.plain)
            .disabled(left == nil || right == nil)
            .opacity(left == nil || right == nil ? 0.4 : 1)
            .accessibilityLabel("Swap the two cycles")

            selectionChip(.right, snapshot: rightSnapshot)
        }
    }

    private func selectionChip(_ side: PickerSide, snapshot: CycleSnapshot?) -> some View {
        Button {
            pickerSide = side
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Circle()
                    .fill(side == .left ? Theme.primary : Theme.sage)
                    .frame(width: 6, height: 6)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(snapshot?.title ?? "Choose a cycle")
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryInk)
                    }
                    Text(snapshot?.subtitle ?? "Tap to pick")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(side == .left ? "First cycle" : "Second cycle")
    }

    // MARK: Hero

    private func heroCard(_ left: CycleSnapshot, _ right: CycleSnapshot) -> some View {
        HStack(alignment: .top, spacing: 10) {
            heroColumn(left, dark: true)
            heroColumn(right, dark: false)
        }
    }

    private func heroColumn(_ snapshot: CycleSnapshot, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.title)
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(dark ? Theme.onHero : Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Text(snapshot.subtitle)
                .font(.system(size: 10))
                .foregroundStyle(dark ? Theme.onHeroSecondary : Theme.secondaryInk)
                .lineLimit(1)

            Text(dateText(snapshot))
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.9)
                .foregroundStyle(dark ? Theme.onHeroSecondary : Theme.tertiaryInk)
                .lineLimit(1)

            ratingStars(snapshot.rating, dark: dark)
                .padding(.top, 2)

            Spacer(minLength: 8)

            Text(snapshot.dryYieldGrams.map { Format.weight($0, unit: unit) } ?? "—")
                .font(Theme.serif(26))
                .foregroundStyle(dark ? Theme.onHero : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("Dry yield")
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(dark ? Theme.onHeroSecondary : Theme.tertiaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 158, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(dark ? Theme.hero : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(dark ? Color.clear : Theme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func ratingStars(_ rating: Double?, dark: Bool) -> some View {
        if let rating {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= Int(rating.rounded()) ? "star.fill" : "star")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(
                            index <= Int(rating.rounded())
                                ? (dark ? Theme.primaryBright : Theme.primary)
                                : (dark ? Theme.onHeroSecondary : Theme.tertiaryInk)
                        )
                }
            }
            .accessibilityLabel("\(String(format: "%.1f", rating)) out of 5")
        } else {
            Text("Not rated")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(dark ? Theme.onHeroSecondary : Theme.tertiaryInk)
        }
    }

    private func dateText(_ snapshot: CycleSnapshot) -> String {
        if snapshot.isAverage {
            return "\(snapshot.sampleCount) cycle\(snapshot.sampleCount == 1 ? "" : "s")"
        }
        guard let date = snapshot.harvestDate else { return "Harvest date not logged" }
        return Format.shortDate(date)
    }

    // MARK: Metrics

    private func metricsCard(_ left: CycleSnapshot, _ right: CycleSnapshot) -> some View {
        let rows = metricRows(left, right)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    metricRowView(rows[index])
                    if index != rows.count - 1 {
                        Divider()
                            .overlay(Theme.hairline)
                            .padding(.vertical, 14)
                    }
                }
            }

            Text("Feed volume counts the feed logged for each plant's room during its flower window.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private func metricRows(_ left: CycleSnapshot, _ right: CycleSnapshot) -> [MetricRow] {
        [
            makeMetric(
                "Dry yield",
                left: left.dryYieldGrams,
                right: right.dryYieldGrams,
                leftText: left.dryYieldGrams.map { Format.weight($0, unit: unit) } ?? "—",
                rightText: right.dryYieldGrams.map { Format.weight($0, unit: unit) } ?? "—"
            ) { leftValue, rightValue in
                let more = rightValue > leftValue
                let bigger = max(leftValue, rightValue)
                let smaller = min(leftValue, rightValue)
                var text = "\(Format.weight(bigger - smaller, unit: unit)) \(more ? "more" : "less")"
                if smaller > 0 {
                    let percent = Int((((bigger - smaller) / smaller) * 100).rounded())
                    text += " · \(percent)% \(more ? "heavier" : "lighter")"
                }
                return (text, Theme.primary)
            },

            makeMetric(
                "Grams per watt",
                left: left.gramsPerWatt,
                right: right.gramsPerWatt,
                leftText: gramsPerWattText(left.gramsPerWatt),
                rightText: gramsPerWattText(right.gramsPerWatt)
            ) { leftValue, rightValue in
                let more = rightValue > leftValue
                let amount = abs(rightValue - leftValue)
                var text = "\(String(format: "%.2f", amount)) g/W \(more ? "more" : "less")"
                let smaller = min(leftValue, rightValue)
                if smaller > 0 {
                    let percent = Int((amount / smaller * 100).rounded())
                    text += " · \(percent)% \(more ? "higher" : "lower")"
                }
                return (text, Theme.primary)
            },

            makeMetric(
                "Dry-to-wet ratio",
                left: left.dryToWetRatio,
                right: right.dryToWetRatio,
                leftText: percentText(left.dryToWetRatio),
                rightText: percentText(right.dryToWetRatio)
            ) { leftValue, rightValue in
                let points = Int((abs(rightValue - leftValue) * 100).rounded())
                return ("\(points) points \(rightValue > leftValue ? "higher" : "lower")", Theme.primary)
            },

            makeMetric(
                "Days in flower",
                left: left.daysInFlower.map { Double($0) },
                right: right.daysInFlower.map { Double($0) },
                leftText: left.daysInFlower.map { Format.dayCount($0) } ?? "—",
                rightText: right.daysInFlower.map { Format.dayCount($0) } ?? "—"
            ) { leftValue, rightValue in
                let days = Int(abs(rightValue - leftValue).rounded())
                if rightValue > leftValue {
                    return ("\(Format.dayCount(days)) longer", Theme.amber)
                }
                return ("\(Format.dayCount(days)) sooner", Theme.primary)
            },

            makeMetric(
                "Feed volume",
                left: left.feedVolumeLiters,
                right: right.feedVolumeLiters,
                leftText: left.feedVolumeLiters.map { Format.volume($0, unit: unit) } ?? "—",
                rightText: right.feedVolumeLiters.map { Format.volume($0, unit: unit) } ?? "—"
            ) { leftValue, rightValue in
                let more = rightValue > leftValue
                return ("\(Format.volume(abs(rightValue - leftValue), unit: unit)) \(more ? "more" : "less")", Theme.primary)
            },

            makeMetric(
                "Rating",
                left: left.rating,
                right: right.rating,
                leftText: ratingText(left.rating),
                rightText: ratingText(right.rating)
            ) { leftValue, rightValue in
                let amount = abs(rightValue - leftValue)
                let more = rightValue > leftValue
                return ("\(numberText(amount)) \(more ? "higher" : "lower")", Theme.primary)
            }
        ]
    }

    private func makeMetric(
        _ title: String,
        left: Double?,
        right: Double?,
        leftText: String,
        rightText: String,
        detail: (Double, Double) -> (String, Color)
    ) -> MetricRow {
        var difference = "Not recorded"
        var tint = Theme.tertiaryInk
        var direction = 0

        if let leftValue = left, let rightValue = right {
            if abs(leftValue - rightValue) < 0.0001 {
                difference = "The same"
                tint = Theme.secondaryInk
            } else {
                let result = detail(leftValue, rightValue)
                difference = result.0
                tint = result.1
                direction = rightValue > leftValue ? 1 : -1
            }
        } else if left != nil || right != nil {
            difference = "Not recorded on one side"
        }

        return MetricRow(
            title: title,
            leftValue: left,
            rightValue: right,
            leftText: leftText,
            rightText: rightText,
            difference: difference,
            tint: tint,
            direction: direction
        )
    }

    private func metricRowView(_ row: MetricRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.title)
                    .font(Theme.sans(10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(Theme.secondaryInk)

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text(row.difference)
                        .multilineTextAlignment(.trailing)
                    if row.direction != 0 {
                        Image(systemName: row.direction > 0 ? "arrow.right" : "arrow.left")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .font(Theme.sans(11, weight: .semibold))
                .foregroundStyle(row.tint)
            }

            VStack(spacing: 4) {
                metricBar(
                    value: row.leftValue,
                    maxValue: row.maxValue,
                    tint: Theme.primary,
                    text: row.leftText
                )
                metricBar(
                    value: row.rightValue,
                    maxValue: row.maxValue,
                    tint: Theme.sage,
                    text: row.rightText
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func metricBar(value: Double?, maxValue: Double, tint: Color, text: String) -> some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.surfaceSunken)
                    if let value, maxValue > 0 {
                        Capsule()
                            .fill(tint)
                            .frame(width: max(5, geometry.size.width * min(1, max(0, value) / maxValue)))
                    }
                }
            }
            .frame(height: 7)

            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.secondaryInk)
                .frame(width: 58, alignment: .trailing)
        }
    }

    private func gramsPerWattText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f g/W", value)
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }

    private func ratingText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f / 5", value)
    }

    private func numberText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", value)
    }

    // MARK: Notes

    private func notesCard(_ left: CycleSnapshot, _ right: CycleSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("What you said")
            noteBlock(left)
            Divider().overlay(Theme.hairline)
            noteBlock(right)
        }
        .growCard()
    }

    private func noteBlock(_ snapshot: CycleSnapshot) -> some View {
        let note = snapshot.tastingNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.title)
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Theme.secondaryInk)
                .lineLimit(1)

            if note.isEmpty {
                Text("No tasting notes for this cycle.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.tertiaryInk)
            } else {
                Text("“\(note)”")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Summary

    private func summaryCard(_ left: CycleSnapshot, _ right: CycleSnapshot) -> some View {
        Text(summaryText(left, right))
            .font(Theme.sans(12))
            .foregroundStyle(Theme.primary)
            .fixedSize(horizontal: false, vertical: true)
            .growCard(fill: Theme.sageSoft, padding: 16)
    }

    private func summaryText(_ left: CycleSnapshot, _ right: CycleSnapshot) -> String {
        var parts: [String] = []

        if let leftRoom = left.roomName, let rightRoom = right.roomName {
            if leftRoom == rightRoom {
                parts.append("Both cycles ran in \(leftRoom).")
            } else {
                parts.append("\(left.title) ran in \(leftRoom); \(right.title) in \(rightRoom).")
            }
        }

        if let leftDays = left.daysInFlower,
           let rightDays = right.daysInFlower,
           leftDays != rightDays {
            let sooner = leftDays < rightDays ? left : right
            parts.append("\(sooner.title) finished \(Format.dayCount(abs(leftDays - rightDays))) sooner.")
        } else if let leftYield = left.dryYieldGrams,
                  let rightYield = right.dryYieldGrams,
                  abs(leftYield - rightYield) > 0.05 {
            let heavier = leftYield > rightYield ? left : right
            parts.append("\(heavier.title) yielded \(Format.weight(abs(leftYield - rightYield), unit: unit)) more.")
        }

        if parts.isEmpty {
            return "Two cycles, recorded side by side. Add weights, feed logs and ratings for a fuller comparison."
        }
        return parts.prefix(2).joined(separator: " ")
    }

    // MARK: Empty state

    private var pickPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pick a second cycle")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Mark another plant as harvested — or finish another cycle of this strain — and its numbers sit beside this one.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton("Choose a cycle", systemImage: "chart.bar.xaxis") {
                pickerSide = .right
            }
        }
        .growCard()
    }

    // MARK: Picker

    private func defaultRightSource() -> CycleSource? {
        if let other = finishedPlants.first(where: { $0.persistentModelID != plant.persistentModelID }) {
            return .plant(other)
        }
        if let strain = plant.strain, CycleMetrics.canAverage(strain) {
            return .strainAverage(strain)
        }
        return nil
    }

    private func currentSource(for side: PickerSide) -> CycleSource? {
        side == .left ? left : right
    }

    private func pickerOptions(for side: PickerSide) -> [CyclePickerOption] {
        let other = side == .left ? right : left
        let excludedPlantID = other?.plant?.persistentModelID

        var options: [CyclePickerOption] = []

        if let strain = plant.strain, CycleMetrics.canAverage(strain) {
            let snapshot = CycleMetrics.average(for: strain)
            options.append(
                CyclePickerOption(
                    id: "average-\(String(describing: strain.persistentModelID))",
                    title: "\(strain.displayName) average",
                    subtitle: "Your own completed cycles",
                    detail: averageDetail(snapshot),
                    systemImage: "chart.bar.xaxis",
                    isSelected: isSelected(.strainAverage(strain), side: side),
                    source: .strainAverage(strain)
                )
            )
        }

        for candidate in finishedPlants where candidate.persistentModelID != excludedPlantID {
            options.append(
                CyclePickerOption(
                    id: "plant-\(String(describing: candidate.persistentModelID))",
                    title: candidate.displayName,
                    subtitle: candidate.displayStrain,
                    detail: plantDetail(candidate),
                    systemImage: candidate.stage.systemImage,
                    isSelected: isSelected(.plant(candidate), side: side),
                    source: .plant(candidate)
                )
            )
        }

        return options
    }

    private func isSelected(_ source: CycleSource, side: PickerSide) -> Bool {
        guard let current = currentSource(for: side) else { return false }
        switch (source, current) {
        case (.plant(let a), .plant(let b)):
            return a.persistentModelID == b.persistentModelID
        case (.strainAverage(let a), .strainAverage(let b)):
            return a.persistentModelID == b.persistentModelID
        default:
            return false
        }
    }

    private func plantDetail(_ plant: Plant) -> String {
        var parts: [String] = []
        if let date = CycleMetrics.harvestDate(for: plant) {
            parts.append("Harvested \(Format.shortDate(date))")
        } else {
            parts.append("Harvest date not logged")
        }
        if let dry = plant.dryWeightGrams {
            parts.append(Format.weight(dry, unit: unit))
        }
        return parts.joined(separator: " · ")
    }

    private func averageDetail(_ snapshot: CycleSnapshot?) -> String {
        guard let snapshot else { return "No completed cycles" }
        let cycles = "\(snapshot.sampleCount) cycle\(snapshot.sampleCount == 1 ? "" : "s")"
        guard let dry = snapshot.dryYieldGrams else { return cycles }
        return "\(cycles) · avg \(Format.weight(dry, unit: unit))"
    }
}

// MARK: - Picker

struct CyclePickerOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let systemImage: String
    let isSelected: Bool
    let source: CycleSource
}

struct CyclePickerSheet: View {
    let title: String
    let options: [CyclePickerOption]
    let onSelect: (CycleSource) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if options.isEmpty {
                        Text("No other finished cycles yet. Harvest another plant, or finish another cycle of this strain, to compare against this one.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .growCard(padding: 16)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(options) { option in
                                Button {
                                    onSelect(option.source)
                                    dismiss()
                                } label: {
                                    optionRow(option)
                                }
                                .buttonStyle(.plain)

                                if option.id != options.last?.id {
                                    Divider().overlay(Theme.hairline)
                                }
                            }
                        }
                        .growCard(padding: 14)
                    }
                }
                .padding(20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func optionRow(_ option: CyclePickerOption) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sageSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: option.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(option.subtitle)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
                Text(option.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if option.isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
