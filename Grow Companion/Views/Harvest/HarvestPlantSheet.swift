//
//  HarvestPlantSheet.swift
//  Grow Companion
//
//  Harvest a plant: wet weight in grams or ounces, the predicted dry weight
//  from the grower's own history or the 22% default, and the drying profile.
//

import SwiftUI
import SwiftData

struct HarvestPlantSheet: View {
    let plant: Plant

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @Query(sort: \Plant.plantedAt) private var allPlants: [Plant]

    @State private var wetText = ""
    @State private var weightUnit: UnitSystem = .metric
    @State private var profile: DryingProfile = .hangDry
    @State private var startDate = Date()

    private var wetGrams: Double? {
        guard let value = CareInput.number(wetText), value > 0 else { return nil }
        return weightUnit == .metric ? value : value * 28.3495
    }

    private var prediction: DryPrediction? {
        guard let wetGrams else { return nil }
        return HarvestLog.predict(plants: allPlants, wetGrams: wetGrams)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Harvest \(plant.displayName)")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Weigh the plant, then start a drying and curing log. The predicted dry weight uses your own harvests once you have them.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Wet weight")
                        HStack(spacing: 10) {
                            TextField(weightUnit == .metric ? "e.g. 420" : "e.g. 14.8", text: $wetText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                                .font(Theme.sans(18, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.surfaceSunken)
                                )

                            Picker("Unit", selection: $weightUnit) {
                                Text("g").tag(UnitSystem.metric)
                                Text("oz").tag(UnitSystem.imperial)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                    }

                    if let prediction {
                        VStack(alignment: .leading, spacing: 6) {
                            CareInput.label("Predicted dry weight")
                            Text("\(Format.weight(prediction.grams, unit: weightUnit))")
                                .font(Theme.serif(30))
                                .foregroundStyle(Theme.primary)
                            Text(prediction.basisText)
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .growCard(fill: Theme.sageSoft, padding: 16)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Drying profile")
                        ForEach(DryingProfile.allCases) { option in
                            Button {
                                profile = option
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: option == .hangDry ? "wind" : "fan")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(profile == option ? Theme.primary : Theme.secondaryInk)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(option.title)
                                            .font(Theme.sans(15, weight: .semibold))
                                            .foregroundStyle(Theme.ink)
                                        Text(option.subtitle)
                                            .font(Theme.sans(12))
                                            .foregroundStyle(Theme.secondaryInk)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: profile == option ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 19))
                                        .foregroundStyle(profile == option ? Theme.primary : Theme.tertiaryInk)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Theme.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(profile == option ? Theme.primary.opacity(0.45) : Theme.hairline, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("Drying started")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        DatePicker("", selection: $startDate)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .growCard(padding: 14)

                    PrimaryButton("Start drying", systemImage: "wind", isEnabled: wetGrams != nil) {
                        save()
                    }

                    if wetGrams == nil {
                        Text("Enter a wet weight to start the log.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.tertiaryInk)
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
            }
        }
        .onAppear {
            weightUnit = UnitSystem(rawValue: unitRaw) ?? .metric
            if let wet = plant.wetWeightGrams {
                wetText = weightUnit == .metric
                    ? String(format: "%.0f", wet)
                    : String(format: "%.1f", wet / 28.3495)
            }
        }
        .onChange(of: weightUnit) { oldUnit, newUnit in
            guard oldUnit != newUnit, let value = CareInput.number(wetText) else { return }
            let grams = oldUnit == .metric ? value : value * 28.3495
            wetText = newUnit == .metric
                ? String(format: "%.0f", grams)
                : String(format: "%.1f", grams / 28.3495)
        }
    }

    private func save() {
        guard let wetGrams else { return }

        plant.wetWeightGrams = wetGrams
        plant.harvestedAt = plant.harvestedAt ?? Date()

        if plant.stage != .harvest {
            plant.stage = .harvest
            let event = StageEvent(stage: .harvest, date: Date())
            context.insert(event)
            event.plant = plant
        }

        let session = DryingSession(startedAt: startDate, phase: .drying, profile: profile)
        context.insert(session)
        session.plant = plant

        try? context.save()
        dismiss()
    }
}
