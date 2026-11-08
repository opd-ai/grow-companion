//
//  RuleChangeReviewView.swift
//  Grow Companion
//
//  The notice that the bundled rule pack changed, and the review that shows
//  what changed, how each saved calculation compares and what the citation is.
//  Acknowledging records that the grower saw the review; it changes no record.
//

import SwiftUI
import SwiftData

struct RuleUpdateBanner: View {
    let events: [RuleEvaluationEvent]
    let action: () -> Void

    private var priorVersions: [String] {
        var seen = Set<String>()
        return events.compactMap { event in
            seen.insert(event.priorPackVersion).inserted ? event.priorPackVersion : nil
        }
    }

    private var newVersion: String {
        events.first?.newPackVersion ?? RulePack.version
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath.circle")
                    .font(.system(size: 16, weight: .semibold))
                Text("Compliance rule update")
                    .font(Theme.sans(15, weight: .semibold))
            }
            .foregroundStyle(Theme.amber)

            Text("The bundled rule pack moved from \(priorVersions.joined(separator: ", ")) to \(newVersion). \(events.count) saved calculation\(events.count == 1 ? " was" : "s were") re-checked.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                HStack {
                    Text("Review rule update")
                        .font(Theme.sans(13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.amber)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Review the compliance rule update")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.amberSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.amber.opacity(0.25), lineWidth: 1)
        )
    }
}

struct RuleChangeReviewView: View {
    let events: [RuleEvaluationEvent]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var errorMessage = ""
    @State private var showingError = false

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var pending: [RuleEvaluationEvent] {
        events.filter { !$0.isAcknowledged }
    }

    private var groups: [ReviewGroup] {
        var order: [String] = []
        var grouped: [String: [RuleEvaluationEvent]] = [:]

        for event in pending {
            let key = "\(event.priorPackVersion)|\(event.newPackVersion)"
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(event)
        }

        return order.compactMap { key in
            guard let events = grouped[key], let first = events.first else { return nil }
            return ReviewGroup(
                id: key,
                priorVersion: first.priorPackVersion,
                newVersion: first.newPackVersion,
                events: events
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro

                    ForEach(groups) { group in
                        versionCard(group)
                        changedFieldsCard(group)
                        recordsCard(group)
                        citationCard(group)
                    }

                    PrimaryButton("Acknowledge update", systemImage: "checkmark.seal") {
                        acknowledge()
                    }
                    .disabled(pending.isEmpty)

                    Text("Acknowledging records that you saw this review. It does not accept the law, change any saved calculation or make the rules current — verify the law where you live.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Rule update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Could not save", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What changed")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
            Text("Each saved calculation is compared with the new rule pack using the inputs it stored. Records that cannot be compared are listed as such and are never inferred.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func versionCard(_ group: ReviewGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(group.priorVersion) → \(group.newVersion)")
                .font(Theme.sans(17, weight: .semibold))
                .foregroundStyle(Theme.ink)
            if let first = group.events.first {
                InfoRow(
                    label: "Previous rules verified",
                    value: RulePack.displayDate(first.priorRuleVerifiedOn)
                )
                InfoRow(
                    label: "New rules verified",
                    value: RulePack.displayDate(first.newRuleVerifiedOn)
                )
            }
            Text("\(group.events.count) saved calculation\(group.events.count == 1 ? "" : "s") compared")
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .growCard(padding: 16)
    }

    private func changedFieldsCard(_ group: ReviewGroup) -> some View {
        let fields = fields(in: group)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Changed limits")

            if fields.isEmpty {
                Text("No limit that applied to these records changed in the new pack.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(fields) { field in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(field.label)
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        HStack(alignment: .top, spacing: 14) {
                            valueColumn(
                                title: "Was",
                                value: field.display(previous: true, unit: unit)
                            )
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.tertiaryInk)
                                .padding(.top, 16)
                            valueColumn(
                                title: "Now",
                                value: field.display(previous: false, unit: unit)
                            )
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(field.label): was \(field.display(previous: true, unit: unit)), now \(field.display(previous: false, unit: unit))"
                    )
                }
            }
        }
        .growCard(padding: 16)
    }

    private func valueColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(Theme.tertiaryInk)
            Text(value)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recordsCard(_ group: ReviewGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Saved calculations under this change")

            ForEach(group.events, id: \.eventID) { event in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Format.shortDate(event.evaluatedAt))
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        Pill(
                            text: event.outcome == .comparable ? "Compared" : "Not comparable",
                            systemImage: event.outcome == .comparable ? "checkmark.circle" : "questionmark.circle",
                            tint: event.outcome == .comparable ? Theme.primary : Theme.secondaryInk,
                            fill: event.outcome == .comparable ? Theme.sageSoft : Theme.surfaceSunken
                        )
                    }

                    Text(event.changedSummary)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    if event.outcome == .comparable {
                        ForEach(event.metrics) { metric in
                            if metric.comparable {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(metric.label)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.secondaryInk)
                                    Spacer(minLength: 8)
                                    Text(metric.valueText(previous: false, unit: unit))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Pill(
                                        text: metric.currentLevelValue.title,
                                        systemImage: metric.currentLevelValue.symbolName,
                                        tint: metric.currentLevelValue.tint,
                                        fill: metric.currentLevelValue.softFill
                                    )
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)

                if event.eventID != group.events.last?.eventID {
                    Divider().overlay(Theme.hairline)
                }
            }
        }
        .growCard(padding: 16)
    }

    @ViewBuilder
    private func citationCard(_ group: ReviewGroup) -> some View {
        if let first = group.events.first, !first.citation.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Source rule")
                Text(first.citation)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = URL(string: first.sourceURL), !first.sourceURL.isEmpty {
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

    private func fields(in group: ReviewGroup) -> [RuleFieldChange] {
        var order: [String] = []
        var byField: [String: RuleFieldChange] = [:]

        for event in group.events {
            for field in event.changedFields where byField[field.field] == nil {
                byField[field.field] = field
                order.append(field.field)
            }
        }

        return order.compactMap { byField[$0] }
    }

    private func acknowledge() {
        do {
            try ComplianceHistoryService.acknowledge(pending, in: context)
            dismiss()
        } catch {
            errorMessage = "The acknowledgment could not be saved. Nothing was changed."
            showingError = true
        }
    }
}

private struct ReviewGroup: Identifiable {
    let id: String
    let priorVersion: String
    let newVersion: String
    let events: [RuleEvaluationEvent]
}
