//
//  JurisdictionPickerSheet.swift
//  Grow Companion
//
//  Manual state selection is the default path; nothing is looked up by
//  location unless the user asks for the optional approximation.
//

import SwiftUI
import SwiftData

struct JurisdictionPickerSheet: View {
    @Binding var stateName: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [JurisdictionRule] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return RulePack.states }
        return RulePack.states.filter { $0.stateName.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { rule in
                    Button {
                        stateName = rule.stateName
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.stateName)
                                    .font(Theme.sans(16, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                Text(rule.cultivable ? "Home cultivation allowed" : "No personal home cultivation")
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.tertiaryInk)
                            }
                            Spacer()
                            if rule.stateName == stateName {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.surface)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search states")
            .navigationTitle("State")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
        }
    }
}

struct ChangeJurisdictionSheet: View {
    @Bindable var profile: GrowProfile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var stateName: String = ""
    @State private var county: String = ""
    @State private var showingPicker = false

    private var rule: JurisdictionRule? { RulePack.rule(forStateName: stateName) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader("Your jurisdiction")
                        Text("Pick the state you grow in and, if you like, the county or city. Grow Companion only uses this to choose your limits.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        showingPicker = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("State")
                                    .font(Theme.sans(11, weight: .semibold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.secondaryInk)
                                Text(stateName.isEmpty ? "Choose a state" : stateName)
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
                        TextField("Optional, for your own reference", text: $county)
                            .textFieldStyle(.plain)
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Theme.surfaceSunken)
                            )
                    }

                    if let rule {
                        JurisdictionSummaryCard(rule: rule, confirmedAt: nil) {
                            profile.jurisdictionConfirmedAt = Date()
                        }

                        if !rule.cultivable {
                            Text("This jurisdiction does not permit personal home cultivation. Tracking stays off and the app switches to education only.")
                                .font(Theme.sans(13))
                                .foregroundStyle(Theme.amber)
                                .fixedSize(horizontal: false, vertical: true)
                                .growCard(fill: Theme.amberSoft, padding: 16)
                        }
                    }

                    PrimaryButton("Save jurisdiction", systemImage: "checkmark", isEnabled: rule != nil) {
                        save()
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Change jurisdiction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .sheet(isPresented: $showingPicker) {
                JurisdictionPickerSheet(stateName: $stateName)
            }
        }
        .onAppear {
            stateName = profile.stateName
            county = profile.countyOrCity
        }
    }

    private func save() {
        guard let rule else { return }
        profile.stateName = rule.stateName
        profile.stateCode = rule.stateCode
        profile.countyOrCity = county.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.educationOnly = !rule.cultivable
        profile.jurisdictionConfirmedAt = Date()
        try? context.save()
        dismiss()
    }
}
