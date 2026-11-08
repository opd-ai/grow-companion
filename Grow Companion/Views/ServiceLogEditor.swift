//
//  ServiceLogEditor.swift
//  Grow Companion
//
//  Records one completed service against equipment.
//

import SwiftUI
import SwiftData

struct ServiceLogEditor: View {
    let equipment: Equipment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var note = ""

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
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Log service")
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
    }

    private func save() {
        equipment.lastServicedAt = date
        let record = ServiceRecord(
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            equipment: equipment
        )
        context.insert(record)
        try? context.save()
        dismiss()
    }
}
