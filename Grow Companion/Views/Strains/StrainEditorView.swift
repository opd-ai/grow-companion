//
//  StrainEditorView.swift
//  Grow Companion
//
//  Add or edit a cultivar: name, breeder, type, expected flowering weeks and
//  notes, optionally starting from a bundled template.
//

import SwiftUI
import SwiftData

struct StrainEditorView: View {
    var strain: Strain? = nil
    var onSaved: ((Strain) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var breeder = ""
    @State private var type: StrainType = .hybrid
    @State private var weeks = 9
    @State private var claimedYield = ""
    @State private var parentLines = ""
    @State private var lineageStatus: LineageStatus = .missing
    @State private var breederSource = ""
    @State private var notes = ""
    @State private var appliedTemplateID: String?

    private var isEditing: Bool { strain != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "Edit strain" : "Add a strain")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text("Keep the breeder's figures here. Your own harvest dates are what the app counts flower weeks from once you have a finished cycle.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !isEditing { templatePicker }

                    field("Name", placeholder: "Blue Dream", text: $name)

                    field("Breeder (optional)", placeholder: "Humboldt Seed Organization", text: $breeder)

                    typePicker

                    weeksPicker
                    breederContextEditor

                    notesEditor
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Theme.primary : Theme.tertiaryInk)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Templates

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Start from a template")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StrainCatalog.templates) { template in
                        Button {
                            apply(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.name)
                                    .font(Theme.sans(13, weight: .semibold))
                                Text("\(template.expectedFloweringWeeks) wk")
                                    .font(Theme.sans(10))
                            }
                            .foregroundStyle(appliedTemplateID == template.id ? Theme.primary : Theme.secondaryInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(appliedTemplateID == template.id ? Theme.sageSoft : Theme.surfaceSunken)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            Text("Tapping a template fills in the details below. Everything stays editable.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func apply(_ template: StrainTemplate) {
        name = template.name
        breeder = template.breeder
        type = template.type
        weeks = min(max(template.expectedFloweringWeeks, 5), 16)
        let reference = StrainCatalog.referenceContext(for: template.breeder)
        claimedYield = reference.claimedYield ?? ""
        parentLines = reference.parentLines ?? ""
        lineageStatus = reference.parentLines == nil ? .missing : .documented
        breederSource = reference.source ?? ""
        notes = template.notes
        appliedTemplateID = template.id
    }

    // MARK: Fields

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Type")
            HStack(spacing: 8) {
                ForEach(StrainType.allCases) { option in
                    Button {
                        type = option
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                            Text(option.title)
                                .font(Theme.sans(12, weight: .semibold))
                        }
                        .foregroundStyle(type == option ? Theme.primary : Theme.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(type == option ? Theme.sageSoft : Theme.surfaceSunken)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(type.subtitle)
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var weeksPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Expected flowering")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(weeks) week\(weeks == 1 ? "" : "s")")
                        .font(Theme.sans(18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("The breeder's figure, usually from the pack")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                }
                Spacer(minLength: 8)
                Stepper("Expected flowering weeks", value: $weeks, in: 5...16)
                    .labelsHidden()
                    .tint(Theme.primary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surfaceSunken)
            )
        }
    }

    private var breederContextEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Breeder context")
            Text("These are claims or references from breeder material, not verified results. Keep your own harvest observations in the strain detail.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            field("Claimed yield", placeholder: "High indoor yield", text: $claimedYield)
            field("Parent lines", placeholder: "Parent names or lineage reference", text: $parentLines)

            Picker("Lineage status", selection: $lineageStatus) {
                ForEach(LineageStatus.allCases) { status in
                    Label(status.title, systemImage: status.systemImage).tag(status)
                }
            }
            .pickerStyle(.segmented)

            field("Source", placeholder: "Breeder catalog or reference", text: $breederSource)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceSunken))
    }

    private var notesEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Notes")
            TextEditor(text: $notes)
                .scrollContentBackground(.hidden)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 120)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Growth habit, stretch, feeding quirks, anything worth repeating")
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.tertiaryInk)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(Theme.sans(11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryInk)
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(title)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.sans(16))
                .foregroundStyle(Theme.ink)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
        }
    }

    // MARK: Data

    private func load() {
        guard let strain else { return }
        name = strain.name
        breeder = strain.breeder
        type = strain.type
        weeks = min(max(strain.expectedFloweringWeeks, 5), 16)
        claimedYield = strain.claimedYield
        parentLines = strain.parentLines
        lineageStatus = strain.lineageStatus
        breederSource = strain.breederSource
        notes = strain.notes
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let trimmedBreeder = breeder.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let saved: Strain
        if let strain {
            strain.name = trimmedName
            strain.breeder = trimmedBreeder
            strain.type = type
            strain.expectedFloweringWeeks = max(1, weeks)
            strain.claimedYield = claimedYield.trimmingCharacters(in: .whitespacesAndNewlines)
            strain.parentLines = parentLines.trimmingCharacters(in: .whitespacesAndNewlines)
            strain.lineageStatus = lineageStatus
            strain.breederSource = breederSource.trimmingCharacters(in: .whitespacesAndNewlines)
            strain.notes = trimmedNotes
            saved = strain
        } else {
            let created = Strain(
                name: trimmedName,
                breeder: trimmedBreeder,
                type: type,
                expectedFloweringWeeks: max(1, weeks),
                claimedYield: claimedYield.trimmingCharacters(in: .whitespacesAndNewlines),
                parentLines: parentLines.trimmingCharacters(in: .whitespacesAndNewlines),
                lineageStatus: lineageStatus,
                breederSource: breederSource.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: trimmedNotes
            )
            context.insert(created)
            saved = created
        }

        try? context.save()
        onSaved?(saved)
        dismiss()
    }
}
