//
//  TreatmentEditor.swift
//  Grow Companion
//
//  Log or edit one treatment applied to a plant or room.
//

import SwiftUI
import SwiftData

struct TreatmentEditor: View {
    let plant: Plant?
    let room: Room?
    var treatment: Treatment? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var productName = ""
    @State private var dose = ""
    @State private var date = Date()
    @State private var hasWithdrawal = false
    @State private var withdrawalText = ""
    @State private var note = ""
    @State private var showingDelete = false

    private var isEditing: Bool { treatment != nil }
    private var targetName: String { plant?.displayName ?? room?.name ?? "this grow" }
    private var withdrawalDays: Int? {
        guard hasWithdrawal, let value = Int(withdrawalText.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "Edit treatment" : "Log treatment")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text("Record what was applied to \(targetName). This is a log only; the app does not recommend products.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    field("Product name", placeholder: "What was applied", text: $productName)
                    field("Dose", placeholder: "Amount and unit", text: $dose)

                    HStack {
                        Text("Date")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Withdrawal period", isOn: $hasWithdrawal)
                            .font(Theme.sans(14, weight: .medium))
                            .tint(Theme.primary)
                        if hasWithdrawal {
                            HStack(spacing: 8) {
                                TextField("0", text: $withdrawalText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                    .font(Theme.sans(16))
                                Text("days")
                                    .font(Theme.sans(14))
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))
                            Text("The end date is calculated from the treatment date.")
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.tertiaryInk)
                        }
                    }
                    .growCard(fill: Theme.surfaceSunken, padding: 14)

                    field("Note (optional)", placeholder: "What you observed or why it was applied", text: $note, axis: .vertical)

                    if isEditing {
                        Button {
                            showingDelete = true
                        } label: {
                            Text("Delete this treatment")
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
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
                        .foregroundStyle(Theme.primary)
                        .disabled(productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear(perform: load)
        .confirmationDialog("Delete this treatment?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Delete treatment", role: .destructive) {
                if let treatment {
                    context.delete(treatment)
                    try? context.save()
                }
                dismiss()
            }
            Button("Keep treatment", role: .cancel) {}
        } message: {
            Text("The record is removed from the treatment history.")
        }
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.sans(11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryInk)
            TextField(placeholder, text: text, axis: axis)
                .textFieldStyle(.plain)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))
        }
    }

    private func load() {
        guard let treatment else { return }
        productName = treatment.productName
        dose = treatment.dose
        date = treatment.date
        hasWithdrawal = treatment.withdrawalDays != nil
        withdrawalText = treatment.withdrawalDays.map(String.init) ?? ""
        note = treatment.note
    }

    private func save() {
        let trimmedName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDose = dose.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let treatment {
            treatment.productName = trimmedName
            treatment.dose = trimmedDose
            treatment.date = date
            treatment.withdrawalDays = withdrawalDays
            treatment.note = trimmedNote
        } else {
            let created = Treatment(
                productName: trimmedName,
                dose: trimmedDose,
                date: date,
                withdrawalDays: withdrawalDays,
                note: trimmedNote,
                plant: plant,
                room: room
            )
            context.insert(created)
        }

        try? context.save()
        dismiss()
    }
}
