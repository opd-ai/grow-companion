//
//  ServiceRecordEditor.swift
//  Grow Companion
//
//  Records one completed service against equipment, or corrects and removes a
//  service that is already on record.
//

import SwiftUI
import SwiftData

struct ServiceRecordEditor: View {
    let equipment: Equipment
    var record: ServiceRecord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var note = ""
    @State private var showingDelete = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var isEditing: Bool { record != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Equipment")
                        Spacer()
                        Text(equipment.name).foregroundStyle(Theme.secondaryInk)
                    }
                    DatePicker("Service date", selection: $date, displayedComponents: .date)
                }
                Section("Note") {
                    TextField("What was serviced?", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDelete = true
                        } label: {
                            Text("Delete this service")
                        }
                    } footer: {
                        Text("Deleting the record moves “last serviced” back to the latest service still on record.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(isEditing ? "Edit service" : "Log service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).foregroundStyle(Theme.primary)
                }
            }
        }
        .onAppear(perform: load)
        .confirmationDialog(
            "Delete this service?",
            isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete this service", role: .destructive) { deleteRecord() }
            Button("Keep it", role: .cancel) {}
        }
        .alert("Could not delete", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func load() {
        guard let record else { return }
        date = record.date
        note = record.note
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let record {
                try EquipmentService.update(record, date: date, note: trimmedNote, in: context)
            } else {
                try EquipmentService.add(date: date, note: trimmedNote, to: equipment, in: context)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func deleteRecord() {
        guard let record else { return }

        do {
            try EquipmentService.delete(record, in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
