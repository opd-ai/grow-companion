//
//  LabResultEditor.swift
//  Grow Companion
//
//  Types one lab report in: the date, the lab, the figures exactly as printed,
//  and the grower's confirmation that they copied them. Nothing is saved until
//  that confirmation is given.
//

import SwiftUI
import SwiftData

struct LabResultEditor: View {
    let plant: Plant
    var result: LabResult?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var reportDate = Date()
    @State private var labName = ""
    @State private var notes = ""
    @State private var confirmed = false
    @State private var rows: [FigureRow] = [FigureRow()]
    @State private var errorMessage = ""
    @State private var showingDelete = false

    private struct FigureRow: Identifiable {
        var id = UUID()
        var name = ""
        var value = ""
        var unit = ""
        var flagged = false
    }

    private var isEditing: Bool { result != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    detailsCard
                    figuresCard
                    confirmationCard

                    if !errorMessage.isEmpty {
                        CareInput.warning(errorMessage)
                    }

                    PrimaryButton(
                        isEditing ? "Save changes" : "Save report",
                        systemImage: "checkmark",
                        isEnabled: confirmed
                    ) {
                        save()
                    }

                    if isEditing {
                        deleteButton
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
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
            }
        }
        .onAppear(perform: load)
        .confirmationDialog(
            "Delete this report?",
            isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete report", role: .destructive) { deleteResult() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The figures and notes are removed from this plant.")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isEditing ? "Edit lab report" : "Add a lab report")
                .font(Theme.serif(28))
                .foregroundStyle(Theme.ink)
            Text("Copy the figures exactly as the report prints them. The app stores them as your record and never interprets, averages or grades them.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Details

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("The report")

            DatePicker("Report date", selection: $reportDate, displayedComponents: .date)
                .font(Theme.sans(14))
                .tint(Theme.primary)

            field("Lab", placeholder: "Optional", text: $labName)

            VStack(alignment: .leading, spacing: 5) {
                Text("Notes")
                    .font(Theme.sans(11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryInk)
                TextField("Optional", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2...5)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )
            }
        }
        .growCard()
    }

    // MARK: Figures

    private var figuresCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Figures", subtitle: "Name, the value as printed, and its unit")

            ForEach(Array($rows.enumerated()), id: \.element.id) { index, row in
                figureRow(row, index: index)
            }

            SecondaryButton("Add another figure", systemImage: "plus") {
                rows.append(FigureRow())
            }
        }
        .growCard()
    }

    private func figureRow(_ row: Binding<FigureRow>, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Figure \(index + 1)")
                    .font(Theme.sans(11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .foregroundStyle(Theme.secondaryInk)

                Spacer(minLength: 4)

                if rows.count > 1 {
                    Button {
                        rows.removeAll { $0.id == row.wrappedValue.id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove figure \(index + 1)")
                }
            }

            field("Name", placeholder: "Total THC", text: row.name)

            HStack(spacing: 10) {
                field("Value", placeholder: "18.4", text: row.value)
                field("Unit", placeholder: "%", text: row.unit)
            }

            Toggle(isOn: row.flagged) {
                Text("The report marks this figure as outside a limit")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Theme.primary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surfaceSunken)
        )
    }

    // MARK: Confirmation

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $confirmed) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("I copied these figures from the report")
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Required. The app holds your record, not a verified result, and nothing here is a diagnosis or a claim about what this flower can do.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.primary)
        }
        .growCard(fill: Theme.sageSoft, padding: 16)
    }

    // MARK: Bits

    private func field(_ title: String, placeholder: String = "", text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(Theme.sans(11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryInk)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surface)
                )
        }
    }

    private var deleteButton: some View {
        Button {
            showingDelete = true
        } label: {
            Text("Delete this report")
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private func load() {
        guard let result else { return }

        reportDate = result.reportDate
        labName = result.labName
        notes = result.notes
        confirmed = result.userConfirmed

        let figures = result.analytes
        rows = figures.isEmpty
            ? [FigureRow()]
            : figures.map { FigureRow(name: $0.name, value: $0.value, unit: $0.unit, flagged: $0.flagged) }
    }

    private func save() {
        errorMessage = ""

        let draft = LabResultDraft(
            reportDate: reportDate,
            labName: labName,
            notes: notes,
            analytes: rows.map {
                LabAnalyte(name: $0.name, value: $0.value, unit: $0.unit, flagged: $0.flagged)
            },
            userConfirmed: confirmed
        )

        do {
            try LabResultService.save(draft, existing: result, for: plant, in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteResult() {
        guard let result else { return }

        do {
            try LabResultService.delete(result, in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
