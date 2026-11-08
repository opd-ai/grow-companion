//
//  ComplianceView.swift
//  Grow Companion
//
//  The rules tab: the jurisdiction's limits in plain language, what the app
//  counts right now, and the always-visible legal caveats.
//

import SwiftUI
import SwiftData

struct ComplianceView: View {
    let profile: GrowProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \Room.createdAt) private var rooms: [Room]

    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var showingChange = false

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }
    private var rule: JurisdictionRule? { profile.rule }

    private var report: ComplianceReport? {
        guard let rule else { return nil }
        return ComplianceEngine.report(
            plants: plants,
            rooms: rooms,
            rule: rule,
            warningThreshold: warningThreshold
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let rule, let report {
                    JurisdictionSummaryCard(
                        rule: rule,
                        confirmedAt: profile.jurisdictionConfirmedAt
                    ) {
                        profile.jurisdictionConfirmedAt = Date()
                        try? context.save()
                    }

                    snapshotCard(report: report)
                    RulesDetailView(rule: rule)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No jurisdiction yet")
                            .font(Theme.sans(16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Pick the state you grow in and Grow Companion will show the limits that apply.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                        SecondaryButton("Choose jurisdiction", systemImage: "mappin.and.ellipse") {
                            showingChange = true
                        }
                    }
                    .growCard()
                }

                FederalNoticeCard()
                VerificationDutyCard()
            }
            .padding(20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingChange) {
            ChangeJurisdictionSheet(profile: profile)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My rules")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text(profile.jurisdictionLabel.isEmpty ? "No jurisdiction selected" : profile.jurisdictionLabel)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
            Button {
                showingChange = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Change jurisdiction")
                        .font(Theme.sans(12, weight: .semibold))
                }
                .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)
        }
    }

    private func snapshotCard(report: ComplianceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Right now", subtitle: "Computed on this device")
            snapshotRow(
                "Counted plants",
                value: "\(report.countedPlants) / \(report.plantLimit.map(String.init) ?? "—")",
                level: report.plantLevel
            )
            Divider().overlay(Theme.hairline)
            snapshotRow(
                "Stored flower",
                value: "\(Format.weight(report.possessionGrams, unit: unit)) / \(Format.weightLimit(report.possessionLimitGrams, unit: unit))",
                level: report.possessionLevel
            )
            Divider().overlay(Theme.hairline)
            snapshotRow(
                "Canopy",
                value: report.canopyLimitSqM == nil
                    ? Format.area(report.canopySqM, unit: unit)
                    : "\(Format.area(report.canopySqM, unit: unit)) / \(Format.areaLimit(report.canopyLimitSqM, unit: unit))",
                level: report.canopyLevel
            )
        }
        .growCard(padding: 16)
    }

    private func snapshotRow(_ title: String, value: String, level: ComplianceLevel) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Pill(text: level.title, systemImage: level.symbolName, tint: level.tint, fill: level.softFill)
        }
        .accessibilityElement(children: .combine)
    }
}
