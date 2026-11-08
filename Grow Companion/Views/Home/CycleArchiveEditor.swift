import SwiftUI
import SwiftData

struct CycleArchiveEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Plant.plantedAt, order: .forward) private var plants: [Plant]

    @State private var name = ""
    @State private var completedAt = Date()
    @State private var selectedIDs = Set<PersistentIdentifier>()

    private var finishedPlants: [Plant] {
        plants.filter { !$0.isArchived && ([.harvest, .cure, .storage].contains($0.stage) || $0.harvestedAt != nil || $0.dryWeightGrams != nil) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Cycle name", text: $name)
                    DatePicker("Completed", selection: $completedAt, displayedComponents: .date)
                } header: { Text("Cycle") }

                Section {
                    if finishedPlants.isEmpty {
                        Text("No finished plants are ready to archive yet.")
                            .foregroundStyle(Theme.secondaryInk)
                    } else {
                        ForEach(finishedPlants) { plant in
                            Button {
                                if selectedIDs.contains(plant.persistentModelID) { selectedIDs.remove(plant.persistentModelID) } else { selectedIDs.insert(plant.persistentModelID) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(plant.displayName).foregroundStyle(Theme.ink)
                                        Text("\(plant.room?.name ?? "No room") · \(plant.stage.title)").font(.caption).foregroundStyle(Theme.secondaryInk)
                                    }
                                    Spacer()
                                    Image(systemName: selectedIDs.contains(plant.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDs.contains(plant.persistentModelID) ? Theme.primary : Theme.tertiaryInk)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: { Text("Plants to archive") }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Archive cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.primary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Archive") { save() }.fontWeight(.semibold).foregroundStyle(Theme.primary).disabled(selectedIDs.isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let archive = CycleArchive(name: name.trimmingCharacters(in: .whitespacesAndNewlines), completedAt: completedAt)
        context.insert(archive)
        for plant in finishedPlants where selectedIDs.contains(plant.persistentModelID) { plant.cycleArchive = archive }
        try? context.save()
        dismiss()
    }
}
