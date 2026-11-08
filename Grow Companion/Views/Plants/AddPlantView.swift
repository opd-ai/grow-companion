//
//  AddPlantView.swift
//  Grow Companion
//

import SwiftUI
import SwiftData

struct AddPlantView: View {
    var preselectedRoom: Room? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]
    @Query(sort: \Strain.name) private var strains: [Strain]
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]

    private var rule: JurisdictionRule? { profiles.first?.rule }

    @State private var name = ""
    @State private var selectedStrain: Strain?
    @State private var showingStrainEditor = false
    @State private var selectedMother: Plant?
    @State private var origin: PlantOrigin = .seed
    @State private var container = ""
    @State private var plantedAt = Date()
    @State private var selectedRoom: Room?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add a plant")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text("Everything here can be changed later. Nothing is uploaded anywhere.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    field("Name", placeholder: "Blue Dream no. 2", text: $name)

                    strainSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Started from")
                            .font(Theme.sans(11, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.secondaryInk)
                        HStack(spacing: 8) {
                            ForEach(PlantOrigin.allCases) { option in
                                Button {
                                    origin = option
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: option.systemImage)
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(option.title)
                                            .font(Theme.sans(12, weight: .semibold))
                                    }
                                    .foregroundStyle(origin == option ? Theme.primary : Theme.secondaryInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(origin == option ? Theme.sageSoft : Theme.surfaceSunken)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if origin != .seed { motherSection }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Room")
                            .font(Theme.sans(11, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.secondaryInk)
                        if rooms.isEmpty {
                            Text("A default grow tent will be created for this plant.")
                                .font(Theme.sans(13))
                                .foregroundStyle(Theme.secondaryInk)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.surfaceSunken)
                                )
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(rooms) { room in
                                        Button {
                                            selectedRoom = room
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: room.type.systemImage)
                                                    .font(.system(size: 12, weight: .semibold))
                                                Text(room.name)
                                                    .font(Theme.sans(13, weight: .semibold))
                                            }
                                            .foregroundStyle(isSelected(room) ? Theme.primary : Theme.secondaryInk)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 9)
                                            .background(
                                                Capsule().fill(isSelected(room) ? Theme.sageSoft : Theme.surfaceSunken)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    field("Container (optional)", placeholder: "5 gallon fabric pot", text: $container)

                    HStack {
                        Text("Planted on")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        DatePicker("", selection: $plantedAt, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )

                    if let rule, !rule.cultivable {
                        Text("Your jurisdiction does not permit home cultivation. This plant will not be added to a tracked grow.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.amber)
                            .fixedSize(horizontal: false, vertical: true)
                            .growCard(fill: Theme.amberSoft, padding: 16)
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
                        .foregroundStyle(canSave ? Theme.primary : Theme.tertiaryInk)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear {
            if selectedRoom == nil { selectedRoom = preselectedRoom ?? rooms.first }
        }
        .onChange(of: origin) { _, newValue in
            if newValue == .seed { selectedMother = nil }
        }
        .sheet(isPresented: $showingStrainEditor) {
            StrainEditorView(onSaved: { created in
                selectedStrain = created
            })
        }
    }

    // MARK: Strain

    private var strainSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Strain")
                    .font(Theme.sans(11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button {
                    showingStrainEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("New strain")
                            .font(Theme.sans(12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.primary)
                }
                .buttonStyle(.plain)
            }

            if strains.isEmpty {
                Text("Your strain library is empty. Add one, or create this plant now and assign a strain later.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        strainChip(title: "No strain", systemImage: "minus.circle", isSelected: selectedStrain == nil) {
                            selectedStrain = nil
                        }
                        ForEach(strains) { strain in
                            strainChip(
                                title: strain.name,
                                systemImage: strain.type.systemImage,
                                isSelected: isSelected(strain)
                            ) {
                                selectedStrain = strain
                            }
                        }
                    }
                }
            }

            if selectedStrain != nil {
                Text(selectedStrainDetail)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectedStrainDetail: String {
        guard let selectedStrain else { return "" }
        let breeder = selectedStrain.breeder.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = [selectedStrain.type.title, "\(selectedStrain.floweringLabel) expected"]
        if !breeder.isEmpty { parts.append(breeder) }
        return parts.joined(separator: " · ")
    }

    private func strainChip(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(Theme.sans(13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Theme.primary : Theme.secondaryInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isSelected ? Theme.sageSoft : Theme.surfaceSunken)
            )
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ strain: Strain) -> Bool {
        selectedStrain?.persistentModelID == strain.persistentModelID
    }

    // MARK: Mother plant

    private var motherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mother plant (optional)")
                .font(Theme.sans(11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryInk)

            if plants.isEmpty {
                Text("No other plants yet. Record the mother once you have a plant in the garden.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        motherChip(
                            title: "No mother",
                            systemImage: "minus.circle",
                            isSelected: selectedMother == nil
                        ) {
                            selectedMother = nil
                        }

                        ForEach(plants) { plant in
                            motherChip(
                                title: plant.displayName,
                                systemImage: "arrow.triangle.branch",
                                isSelected: selectedMother?.persistentModelID == plant.persistentModelID
                            ) {
                                selectedMother = plant
                            }
                        }
                    }
                }

                if let selectedMother {
                    Text("Generation \(selectedMother.generation + 1) · \(selectedMother.displayStrain)")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func motherChip(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(Theme.sans(13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Theme.primary : Theme.secondaryInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isSelected ? Theme.sageSoft : Theme.surfaceSunken)
            )
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ room: Room) -> Bool {
        selectedRoom?.persistentModelID == room.persistentModelID
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
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let room: Room
        if let selectedRoom {
            room = selectedRoom
        } else {
            let created = Room(name: "Grow Room", type: .tent)
            context.insert(created)
            room = created
        }

        let plant = Plant(
            name: trimmedName,
            strainName: selectedStrain?.name ?? "",
            origin: origin,
            container: container.trimmingCharacters(in: .whitespacesAndNewlines),
            plantedAt: plantedAt,
            room: room,
            strain: selectedStrain,
            mother: origin == .seed ? nil : selectedMother
        )
        context.insert(plant)

        let event = StageEvent(stage: plant.stage, date: plantedAt)
        context.insert(event)
        event.plant = plant

        try? context.save()
        dismiss()
    }
}
