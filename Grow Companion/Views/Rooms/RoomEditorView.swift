//
//  RoomEditorView.swift
//  Grow Companion
//
//  Create or edit a room: name, type, placement, canopy area (with unit
//  switching), light type and wattage.
//

import SwiftUI
import SwiftData

struct RoomEditorView: View {
    var room: Room?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var name = ""
    @State private var type: RoomType = .tent
    @State private var isIndoor = true
    @State private var canopyText = ""
    @State private var canopyUnit: UnitSystem = .metric
    @State private var lightType = ""
    @State private var wattsText = ""

    private var isEditing: Bool { room != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "Edit room" : "Add a room")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text("A room is a physical space: a tent, a closet, a whole room, a greenhouse or an outdoor plot.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    field("Name", placeholder: "Room 2 · 4x4 tent", text: $name)

                    VStack(alignment: .leading, spacing: 8) {
                        label("Type")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                            ForEach(RoomType.allCases) { option in
                                Button {
                                    type = option
                                    isIndoor = option.defaultIsIndoor
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
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Placement")
                        Picker("Placement", selection: $isIndoor) {
                            Text("Indoor").tag(true)
                            Text("Outdoor").tag(false)
                        }
                        .pickerStyle(.segmented)
                        Text("Outdoor rooms interact with weather and seasonal rules.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.tertiaryInk)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Canopy area")
                        HStack(spacing: 10) {
                            TextField(canopyUnit == .metric ? "e.g. 1.44" : "e.g. 15.5", text: $canopyText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .font(Theme.sans(16))
                                .foregroundStyle(Theme.ink)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.surfaceSunken)
                                )

                            Picker("Unit", selection: $canopyUnit) {
                                ForEach(UnitSystem.allCases) { system in
                                    Text(system == .metric ? "m²" : "sq ft").tag(system)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 150)
                        }
                        Text("Leave blank if you have not measured the space.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.tertiaryInk)
                    }

                    field("Light type", placeholder: "LED bar", text: $lightType)

                    VStack(alignment: .leading, spacing: 6) {
                        label("Wattage")
                        HStack(spacing: 8) {
                            TextField("e.g. 240", text: $wattsText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .font(Theme.sans(16))
                                .foregroundStyle(Theme.ink)
                            Text("W")
                                .font(Theme.sans(13))
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.surfaceSunken)
                        )
                    }

                    if !isEditing {
                        Text("The light schedule starts at 18/6 with lights on at 6:00. You can change it from the room once it exists.")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.tertiaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .growCard(fill: Theme.surfaceSunken, padding: 16)
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
        .onAppear(perform: load)
        .onChange(of: canopyUnit) { oldUnit, newUnit in
            convertCanopyText(from: oldUnit, to: newUnit)
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
        let preferredUnit = UnitSystem(rawValue: unitRaw) ?? .metric
        canopyUnit = preferredUnit

        guard let room else {
            isIndoor = true
            return
        }
        name = room.name
        type = room.type
        isIndoor = room.isIndoor
        lightType = room.lightType
        wattsText = room.lightWatts > 0 ? "\(room.lightWatts)" : ""
        canopyText = canopyDisplayText(room.canopySquareMeters, unit: preferredUnit)
    }

    private func canopyDisplayText(_ squareMeters: Double?, unit: UnitSystem) -> String {
        guard let squareMeters else { return "" }
        switch unit {
        case .metric:
            return String(format: "%.2f", squareMeters)
        case .imperial:
            return String(format: "%.1f", squareMeters * 10.7639)
        }
    }

    private func canopySquareMeters(_ text: String, unit: UnitSystem) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalized), value > 0 else { return nil }
        switch unit {
        case .metric: return value
        case .imperial: return value / 10.7639
        }
    }

    private func convertCanopyText(from oldUnit: UnitSystem, to newUnit: UnitSystem) {
        guard oldUnit != newUnit else { return }
        guard let squareMeters = canopySquareMeters(canopyText, unit: oldUnit) else {
            canopyText = ""
            return
        }
        canopyText = canopyDisplayText(squareMeters, unit: newUnit)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let canopy = canopySquareMeters(canopyText, unit: canopyUnit)
        let watts = Int(wattsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let trimmedLightType = lightType.trimmingCharacters(in: .whitespacesAndNewlines)

        if let room {
            room.name = trimmedName
            room.type = type
            room.isIndoor = isIndoor
            room.canopySquareMeters = canopy
            room.lightType = trimmedLightType
            room.lightWatts = watts
        } else {
            let newRoom = Room(
                name: trimmedName,
                type: type,
                isIndoor: isIndoor,
                lightType: trimmedLightType,
                lightWatts: watts,
                canopySquareMeters: canopy
            )
            context.insert(newRoom)
        }

        try? context.save()
        dismiss()
    }
}
