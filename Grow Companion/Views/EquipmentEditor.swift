//
//  EquipmentEditor.swift
//  Grow Companion
//
//  Add or edit equipment and its service schedule.
//

import SwiftUI
import SwiftData

struct EquipmentEditor: View {
    var equipment: Equipment? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var name = ""
    @State private var intervalText = "90"
    @State private var lastServicedAt = Date()
    @State private var selectedRoomID: PersistentIdentifier?

    private var isEditing: Bool { equipment != nil }
    private var interval: Int { max(1, Int(intervalText) ?? 90) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Room", selection: $selectedRoomID) {
                        Text("No room").tag(PersistentIdentifier?.none)
                        ForEach(rooms) { room in
                            Text(room.name).tag(Optional(room.persistentModelID))
                        }
                    }
                } header: {
                    Text("Equipment")
                }

                Section {
                    TextField("Days", text: $intervalText)
                        .keyboardType(.numberPad)
                    DatePicker("Last serviced", selection: $lastServicedAt, displayedComponents: .date)
                } header: {
                    Text("Service schedule")
                } footer: {
                    Text("The next service date is calculated from the last serviced date and interval.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(isEditing ? "Edit equipment" : "Add equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.primary)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let equipment else { return }
        name = equipment.name
        intervalText = String(equipment.serviceIntervalDays)
        lastServicedAt = equipment.lastServicedAt
        selectedRoomID = equipment.room?.persistentModelID
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let room = rooms.first { $0.persistentModelID == selectedRoomID }

        if let equipment {
            equipment.name = trimmedName
            equipment.serviceIntervalDays = interval
            equipment.lastServicedAt = lastServicedAt
            equipment.room = room
        } else {
            context.insert(Equipment(name: trimmedName, serviceIntervalDays: interval, lastServicedAt: lastServicedAt, room: room))
        }
        try? context.save()
        dismiss()
    }
}
