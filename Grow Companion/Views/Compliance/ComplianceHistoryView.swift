//
//  ComplianceHistoryView.swift
//  Grow Companion
//
//  The saved compliance calculations, newest first, with a detail view that
//  states exactly which inputs, limits and rule pack produced each one.
//

import SwiftUI
import SwiftData

struct ComplianceHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ComplianceSnapshot.capturedAt, order: .reverse)
    private var snapshots: [ComplianceSnapshot]
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if snapshots.isEmpty {
                        emptyState
                    } else {
                        header
                        snapshotList
                    }
                    footnote
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Compliance history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Saved calculations")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
            Text("\(snapshots.count) record\(snapshots.count == 1 ? "" : "s") of what this app calculated, oldest changes kept exactly as they were saved.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compliance history starts with this update")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Earlier app versions did not save snapshots, so this history begins with the current calculation. It never reconstructs a past result.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private var snapshotList: some View {
        VStack(spacing: 10) {
            ForEach(snapshots, id: \.persistentModelID) { snapshot in
                NavigationLink {
                    ComplianceSnapshotDetailView(snapshot: snapshot)
                } label: {
                    snapshotRow(snapshot)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func snapshotRow(_ snapshot: ComplianceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Format.shortDate(snapshot.capturedAt))
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Pill(
                    text: snapshot.overallLevel.title,
                    systemImage: snapshot.overallLevel.symbolName,
                    tint: snapshot.overallLevel.tint,
                    fill: snapshot.overallLevel.softFill
                )
            }

            Text("\(snapshot.countedPlantTotal) counted · pack \(snapshot.rulePackVersion)")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)

            Text(snapshot.stateName.isEmpty ? snapshot.jurisdictionCode : snapshot.stateName)
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiaryInk)

            if snapshot.isUpgradeBaseline {
                Text("History begins here")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .growCard(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(Format.shortDate(snapshot.capturedAt)), \(snapshot.stateName.isEmpty ? snapshot.jurisdictionCode : snapshot.stateName), rule pack \(snapshot.rulePackVersion), \(snapshot.countedPlantTotal) plants counted, \(snapshot.overallLevel.title)"
        )
    }

    private var footnote: some View {
        Text("Each snapshot records the app's calculation on that date, not a legal conclusion. Verify the current law before you rely on it.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ComplianceSnapshotDetailView: View {
    let snapshot: ComplianceSnapshot

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleCard
                metricsCard
                stagesCard
                citationCard
                noteCard
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Saved calculation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Format.shortDate(snapshot.capturedAt)) · \(Format.time(snapshot.capturedAt))")
                        .font(Theme.serif(22))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(snapshot.stateName.isEmpty ? snapshot.jurisdictionCode : "\(snapshot.stateName) · \(snapshot.jurisdictionCode)")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                }
                Spacer(minLength: 8)
                Pill(
                    text: snapshot.overallLevel.title,
                    systemImage: snapshot.overallLevel.symbolName,
                    tint: snapshot.overallLevel.tint,
                    fill: snapshot.overallLevel.softFill
                )
            }

            Divider().overlay(Theme.hairline)

            InfoRow(label: "Rule pack", value: snapshot.rulePackVersion)
            InfoRow(label: "Rules verified", value: RulePack.displayDate(snapshot.ruleVerifiedOn))
            InfoRow(label: "Warning threshold", value: Format.percent(snapshot.warningThreshold))

            if snapshot.isUpgradeBaseline {
                Text("History begins with this snapshot. No earlier result was reconstructed.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard()
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("What was calculated")

            metricRow(
                title: "Counted plants",
                value: "\(snapshot.countedPlantTotal) / \(snapshot.plantLimit.map(String.init) ?? "—")",
                level: snapshot.plantLevel
            )
            Divider().overlay(Theme.hairline)
            metricRow(
                title: "Stored flower",
                value: "\(Format.weight(snapshot.retainedDryWeightGrams, unit: unit)) / \(Format.weightLimit(snapshot.possessionLimitGrams, unit: unit))",
                level: snapshot.possessionLevel
            )
            Divider().overlay(Theme.hairline)
            metricRow(
                title: "Canopy",
                value: snapshot.canopyLimitSqM == nil
                    ? Format.area(snapshot.canopySquareMeters, unit: unit)
                    : "\(Format.area(snapshot.canopySquareMeters, unit: unit)) / \(Format.areaLimit(snapshot.canopyLimitSqM, unit: unit))",
                level: snapshot.canopyLevel
            )
        }
        .growCard(padding: 16)
    }

    private func metricRow(title: String, value: String, level: ComplianceLevel) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
            Pill(text: level.title, systemImage: level.symbolName, tint: level.tint, fill: level.softFill)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stagesCard: some View {
        if !snapshot.countedStages.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Stages this rule counted")
                ForEach(snapshot.countedStages) { stage in
                    let count = snapshot.stageCounts[stage] ?? 0
                    InfoRow(label: stage.title, value: stageValue(stage: stage, count: count))
                }
            }
            .growCard(padding: 16)
        }
    }

    private func stageValue(stage: PlantStage, count: Int) -> String {
        if stage == .clone && !snapshot.countsClones {
            return count == 0 ? "Not counted" : "\(count) · not counted"
        }
        return "\(count)"
    }

    @ViewBuilder
    private var citationCard: some View {
        if !snapshot.citation.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Source rule")
                Text(snapshot.citation)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = URL(string: snapshot.sourceURL), !snapshot.sourceURL.isEmpty {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Text("Open primary source")
                                .font(Theme.sans(13, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Theme.primary)
                    }
                }
            }
            .growCard(padding: 16)
        }
    }

    private var noteCard: some View {
        Text("This is a record of the app's calculation on that date. A later rule pack does not rewrite it, and it is not legal advice.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}
