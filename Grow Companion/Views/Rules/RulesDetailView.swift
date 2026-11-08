//
//  RulesDetailView.swift
//  Grow Companion
//
//  One jurisdiction's limits in plain language, with the citation, source and
//  review date next to every rule.
//

import SwiftUI

struct RuleDetailCard: View {
    var title: String
    var value: String
    var detail: String
    var rule: JurisdictionRule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(value)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .multilineTextAlignment(.trailing)
            }

            if !detail.isEmpty {
                Text(detail)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            footer
        }
        .growCard(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(rule.citation)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .lineLimit(2)
                if let url = URL(string: rule.sourceURL) {
                    Link("Source", destination: url)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }

            HStack(spacing: 8) {
                Text("Last verified \(RulePack.displayDate(rule.verifiedOn))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryInk)
                if rule.recountNeeded {
                    Pill(
                        text: "Needs re-verification",
                        systemImage: "exclamationmark.triangle",
                        tint: Theme.amber,
                        fill: Theme.amberSoft
                    )
                }
            }
        }
        .padding(.top, 2)
    }
}

struct RulesDetailView: View {
    var rule: JurisdictionRule

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("What the rule says", subtitle: "Reviewed \(RulePack.displayDate(rule.verifiedOn)) · pack \(RulePack.version)")

            if !rule.summary.isEmpty {
                Text(rule.summary)
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 16)
            }

            RuleDetailCard(
                title: "Plant limit",
                value: rule.plantLimitLabel,
                detail: rule.countingNote,
                rule: rule
            )

            if rule.cultivable {
                RuleDetailCard(
                    title: "Possession",
                    value: Format.weightLimit(rule.possessionLimitGrams, unit: unit),
                    detail: "Harvested flower you keep at home counts toward the possession limit, not the plant count.",
                    rule: rule
                )

                RuleDetailCard(
                    title: "Canopy",
                    value: Format.areaLimit(rule.canopyLimitSqM, unit: unit),
                    detail: rule.canopyLimitSqM == nil
                        ? "This state rule does not set a canopy area. Your city or county may."
                        : "Total growing area allowed where the pack records one.",
                    rule: rule
                )

                RuleDetailCard(
                    title: "Indoor or outdoor",
                    value: rule.placementLabel,
                    detail: rule.outdoorAllowed
                        ? "Outdoor plants must still be out of public view in most jurisdictions."
                        : "Plants must be grown in an enclosed indoor space.",
                    rule: rule
                )

                RuleDetailCard(
                    title: "Registration",
                    value: rule.registrationRequired ? "Required" : "Not required",
                    detail: rule.registrationNote.isEmpty
                        ? "No state registration is required for a personal adult-use grow."
                        : rule.registrationNote,
                    rule: rule
                )

                if rule.medicalCardRequired {
                    RuleDetailCard(
                        title: "Medical card",
                        value: "Required",
                        detail: "Home cultivation in this state runs through the registered medical program, not adult use.",
                        rule: rule
                    )
                }

                if let effective = rule.effectiveOn {
                    Text("Effective from \(RulePack.displayDate(effective))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .padding(.leading, 4)
                }
            }
        }
    }
}

struct FederalNoticeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "building.columns")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(LegalCopy.federalTitle)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }

            Text(LegalCopy.federalStatus)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if let url = URL(string: LegalCopy.federalURL) {
                Link("Federal scheduling notice", destination: url)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .growCard(fill: Theme.amberSoft)
        .accessibilityElement(children: .combine)
    }
}

struct VerificationDutyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your verification duty")
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(LegalCopy.verificationDuty)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(LegalCopy.scope)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(fill: Theme.surfaceSunken)
        .accessibilityElement(children: .combine)
    }
}

struct JurisdictionSummaryCard: View {
    var rule: JurisdictionRule
    var confirmedAt: Date?
    var onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Pill(
                    text: rule.cultivable ? "Home grow allowed" : "Not permitted",
                    systemImage: rule.cultivable ? "checkmark.seal" : "nosign",
                    tint: rule.cultivable ? Theme.primary : Theme.amber,
                    fill: rule.cultivable ? Theme.sageSoft : Theme.amberSoft
                )
                if rule.medicalCardRequired {
                    Pill(text: "Medical card", systemImage: "cross.case", tint: Theme.secondaryInk, fill: Theme.surfaceSunken)
                }
                Spacer()
                Text("Pack \(RulePack.version)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryInk)
            }

            Text(rule.summary)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if rule.cityOverrideWarning {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    Text("Cities and counties can be stricter than the state rule. Check your local code before you rely on these numbers.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let confirmedAt {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                    Text("You confirmed this is your jurisdiction on \(Format.shortDate(confirmedAt))")
                        .font(Theme.sans(12))
                }
                .foregroundStyle(Theme.primary)
            } else {
                SecondaryButton("This is my jurisdiction", systemImage: "checkmark") {
                    onConfirm()
                }
            }
        }
        .growCard()
    }
}
