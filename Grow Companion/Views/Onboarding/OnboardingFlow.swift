//
//  OnboardingFlow.swift
//  Grow Companion
//
//  Age attestation, jurisdiction, residence, experience, the rule summary and
//  an optional first plant. Manual state selection is the default; the
//  approximate-location shortcut is opt-in and resolves on device.
//

import SwiftUI
import SwiftData

struct OnboardingDraft {
    var ageConfirmed = false
    var ageAttestedAt: Date?
    var stateName = ""
    var countyOrCity = ""
    var residenceType: ResidenceType = .singleFamily
    var landlordConsent = false
    var experience: ExperienceLevel = .beginner
    var plantName = ""
    var strainName = ""
    var origin: PlantOrigin = .seed
    var container = ""
    var jurisdictionConfirmed = false
}

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context

    @State private var draft = OnboardingDraft()
    @State private var step = 0

    private let stepCount = 6

    private var rule: JurisdictionRule? { RulePack.rule(forStateName: draft.stateName) }

    private var canContinue: Bool {
        switch step {
        case 0: return draft.ageConfirmed
        case 1: return rule != nil
        case 2: return true
        case 3: return true
        case 4: return draft.jurisdictionConfirmed
        case 5: return true
        default: return false
        }
    }

    private var primaryTitle: String {
        switch step {
        case 0: return String(localized: "I understand — continue")
        case 1: return String(localized: "Continue")
        case 2: return String(localized: "Continue")
        case 3: return String(localized: "Continue")
        case 4: return String(localized: "Looks right")
        case 5: return String(localized: "Start growing")
        default: return String(localized: "Continue")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            ScrollView {
                stepContent
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            footer
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            AgeStepView(draft: $draft)
        case 1:
            JurisdictionStepView(draft: $draft)
        case 2:
            ResidenceStepView(draft: $draft)
        case 3:
            ExperienceStepView(draft: $draft)
        case 4:
            RulesStepView(draft: $draft, rule: rule)
        default:
            FirstPlantStepView(draft: $draft, rule: rule)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Theme.primary : Theme.primary.opacity(0.15))
                        .frame(height: 3)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step + 1) of \(stepCount)")

            HStack {
                if step > 0 {
                    Button {
                        step -= 1
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Back")
                                .font(Theme.sans(13, weight: .semibold))
                        }
                        .foregroundStyle(Theme.secondaryInk)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("Step \(step + 1) of \(stepCount)")
                    .font(Theme.sans(11, weight: .medium))
                    .foregroundStyle(Theme.tertiaryInk)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            PrimaryButton(primaryTitle, isEnabled: canContinue) {
                advance()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Theme.background)
    }

    private func advance() {
        if step < stepCount - 1 {
            step += 1
        } else {
            finish()
        }
    }

    private func finish() {
        guard let rule else { return }

        let profile = GrowProfile(
            ageConfirmed: draft.ageConfirmed,
            ageAttestedAt: draft.ageAttestedAt,
            stateCode: rule.stateCode,
            stateName: rule.stateName,
            countyOrCity: draft.countyOrCity.trimmingCharacters(in: .whitespacesAndNewlines),
            residenceType: draft.residenceType,
            landlordConsent: draft.landlordConsent,
            experienceLevel: draft.experience,
            onboardingCompletedAt: Date(),
            jurisdictionConfirmedAt: Date(),
            educationOnly: !rule.cultivable
        )
        context.insert(profile)

        if rule.cultivable {
            let room = Room(name: "Grow Room", type: .tent)
            context.insert(room)

            let plantName = draft.plantName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !plantName.isEmpty {
                let plant = Plant(
                    name: plantName,
                    strainName: draft.strainName.trimmingCharacters(in: .whitespacesAndNewlines),
                    origin: draft.origin,
                    container: draft.container.trimmingCharacters(in: .whitespacesAndNewlines),
                    room: room
                )
                context.insert(plant)

                let event = StageEvent(stage: plant.stage, date: Date())
                context.insert(event)
                event.plant = plant
            }
        }

        try? context.save()
    }
}

// MARK: - Step 1: age and scope

private struct AgeStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Pill(text: "Private by design", systemImage: "lock.shield")

            VStack(alignment: .leading, spacing: 10) {
                Text("A home grow, kept in order.")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Track one plant or a full room from seed to cure. Grow Companion checks your count against your own jurisdiction's limits and never leaves this device.")
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                point("iphone", "Offline first", "Every record is stored on this iPhone, protected while it is locked.")
                point("checkmark.shield", "Rules you can trace", "Each limit shows its citation, source and the date it was last reviewed.")
                point("person.crop.circle", "Personal use only", "No marketplace, no sales, no transfers and no shipping. Ever.")
            }
            .growCard(fill: Theme.hero)

            FederalNoticeCard()

            Button {
                draft.ageConfirmed.toggle()
                draft.ageAttestedAt = draft.ageConfirmed ? Date() : nil
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: draft.ageConfirmed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(draft.ageConfirmed ? Theme.primary : Theme.tertiaryInk)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("I am of legal age to grow where I live")
                            .font(Theme.sans(15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(LegalCopy.ageAttestation)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .growCard(padding: 16)

            Text(LegalCopy.scope)
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primaryBright)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.onHero)
                Text(detail)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.onHeroSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step 2: jurisdiction

private struct JurisdictionStepView: View {
    @Binding var draft: OnboardingDraft

    @State private var showingPicker = false

    private var rule: JurisdictionRule? { RulePack.rule(forStateName: draft.stateName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader("Step 2 · Your jurisdiction")

            VStack(alignment: .leading, spacing: 8) {
                Text("Where do you grow?")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                Text("We use this only to load your plant limits. Grow Companion does not send it anywhere, and no location permission is requested.")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                showingPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("State")
                            .font(Theme.sans(11, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.secondaryInk)
                        Text(draft.stateName.isEmpty ? "Choose a state" : draft.stateName)
                            .font(Theme.sans(16, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryInk)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text("County or city")
                    .font(Theme.sans(11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryInk)
                TextField("Optional — Los Angeles County", text: $draft.countyOrCity)
                    .textFieldStyle(.plain)
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 13, weight: .semibold))
                    Text("No location permission is requested")
                        .font(Theme.sans(14, weight: .semibold))
                }
                .foregroundStyle(Theme.primary)

                Text("Grow Companion never asks for your location and makes no lookup. You choose the state, and that name is stored with your grow profile and nothing else.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let rule {
                rulePreview(rule)
            }
        }
        .sheet(isPresented: $showingPicker) {
            JurisdictionPickerSheet(stateName: $draft.stateName)
        }
    }

    private func rulePreview(_ rule: JurisdictionRule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Pill(
                    text: rule.cultivable ? "Allowed" : "Not permitted",
                    systemImage: rule.cultivable ? "checkmark.seal" : "nosign",
                    tint: rule.cultivable ? Theme.primary : Theme.amber,
                    fill: rule.cultivable ? Theme.sageSoft : Theme.amberSoft
                )
                Spacer()
                Text(rule.plantLimitLabel)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            Text(rule.summary)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if rule.cityOverrideWarning {
                Text("Cities and counties can be stricter than the state. Verify your local code.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !rule.cultivable {
                Text("Tracking will be off. You will still be able to read the rules and the guidance in this app.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard(fill: Theme.surfaceSunken, padding: 16)
    }
}

// MARK: - Step 3: residence

private struct ResidenceStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Step 3 · Your home")

            Text("How is the space you grow in set up?")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(ResidenceType.allCases) { option in
                    Button {
                        draft.residenceType = option
                        if option != .rental { draft.landlordConsent = false }
                    } label: {
                        ChoiceCard(
                            title: option.title,
                            subtitle: option.subtitle,
                            symbol: option.systemImage,
                            isSelected: draft.residenceType == option
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if draft.residenceType == .rental {
                Toggle(isOn: $draft.landlordConsent) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("My landlord has agreed to the grow")
                            .font(Theme.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Some leases forbid cultivation. Keep written permission on hand.")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Theme.primary)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.surface)
                )
            }
        }
    }
}

// MARK: - Step 4: experience

private struct ExperienceStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Step 4 · Your experience")

            Text("How much guidance do you want?")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("This only changes how much explanation the app shows. You can change it in Settings.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(ExperienceLevel.allCases) { option in
                    Button {
                        draft.experience = option
                    } label: {
                        ChoiceCard(
                            title: option.title,
                            subtitle: option.subtitle,
                            symbol: option.systemImage,
                            isSelected: draft.experience == option
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Step 5: rule summary

private struct RulesStepView: View {
    @Binding var draft: OnboardingDraft
    let rule: JurisdictionRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Step 5 · Your rules")

            Text("Check this is your jurisdiction")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let rule {
                JurisdictionSummaryCard(
                    rule: rule,
                    confirmedAt: draft.jurisdictionConfirmed ? Date() : nil,
                    onConfirm: { draft.jurisdictionConfirmed = true }
                )

                RulesDetailView(rule: rule)

                FederalNoticeCard()
            } else {
                Text("Choose a state first so the limits can be shown.")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard()
            }
        }
    }
}

// MARK: - Step 6: first plant

private struct FirstPlantStepView: View {
    @Binding var draft: OnboardingDraft
    let rule: JurisdictionRule?

    private var cultivable: Bool { rule?.cultivable ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Step 6 · Your first plant")

            if cultivable {
                Text("Add a plant, or skip for now")
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("You can add more plants any time from the Home tab. A room called Grow Room is created for you.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                field("Name", placeholder: "Blue Dream no. 1", text: $draft.plantName)
                field("Strain (optional)", placeholder: "Blue Dream", text: $draft.strainName)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Started from")
                        .font(Theme.sans(11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.secondaryInk)
                    HStack(spacing: 8) {
                        ForEach(PlantOrigin.allCases) { option in
                            Button {
                                draft.origin = option
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: option.systemImage)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(option.title)
                                        .font(Theme.sans(12, weight: .semibold))
                                }
                                .foregroundStyle(draft.origin == option ? Theme.primary : Theme.secondaryInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(draft.origin == option ? Theme.sageSoft : Theme.surfaceSunken)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                field("Container (optional)", placeholder: "5 gallon fabric pot", text: $draft.container)
            } else {
                Text("Tracking is off here")
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                Text("Your jurisdiction does not permit personal home cultivation, so Grow Companion will open in education-only mode. The rules and guidance stay available.")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.amberSoft)
            }
        }
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.sans(11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryInk)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.sans(16))
                .foregroundStyle(Theme.ink)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
        }
    }
}

// MARK: - Shared choice card

private struct ChoiceCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.primary : Theme.secondaryInk)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19))
                .foregroundStyle(isSelected ? Theme.primary : Theme.tertiaryInk)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? Theme.primary.opacity(0.45) : Theme.hairline, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
