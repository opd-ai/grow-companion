//
//  FinishCuringSheet.swift
//  Grow Companion
//
//  Ends the cure, records the actual dry weight and moves the plant to storage.
//

import SwiftUI
import SwiftData

struct FinishCuringSheet: View {
    let session: DryingSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var dryText = ""
    @State private var weightUnit: UnitSystem = .metric

    private var dryGrams: Double? {
        guard let value = CareInput.number(dryText), value > 0 else { return nil }
        return weightUnit == .metric ? value : value * 28.3495
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Finish curing")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("Record the actual dry weight and move the plant to storage. You can change the weight later from the plant.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Dry weight")
                        HStack(spacing: 10) {
                            TextField(weightUnit == .metric ? "e.g. 92" : "e.g. 3.2", text: $dryText)
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
                        Text("Leave it blank if you are still weighing; the plant moves to storage either way.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.tertiaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PrimaryButton("Finish curing", systemImage: "archivebox") {
                        save()
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
            if let dry = session.plant?.dryWeightGrams {
                dryText = weightUnit == .metric
                    ? String(format: "%.0f", dry)
                    : String(format: "%.1f", dry / 28.3495)
            }
        }
        .onChange(of: weightUnit) { oldUnit, newUnit in
            guard oldUnit != newUnit, let value = CareInput.number(dryText) else { return }
            let grams = oldUnit == .metric ? value : value * 28.3495
            dryText = newUnit == .metric
                ? String(format: "%.0f", grams)
                : String(format: "%.1f", grams / 28.3495)
        }
    }

    private func save() {
        if let plant = session.plant {
            if let dryGrams {
                plant.dryWeightGrams = dryGrams
            }
            if plant.stage != .storage {
                let event = StageEvent(stage: .storage, date: Date())
                context.insert(event)
                event.plant = plant
                plant.stage = .storage
            }
        }

        session.phase = .finished
        session.endedAt = Date()
        CareNotifications.cancel(identifier: session.burpNotificationIdentifier)

        try? context.save()
        dismiss()
    }
}
