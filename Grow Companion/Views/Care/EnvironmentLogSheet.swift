//
//  EnvironmentLogSheet.swift
//  Grow Companion
//

import SwiftUI
import SwiftData

struct EnvironmentLogSheet: View {
    let room: Room
    var reminder: CareReminder?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var date = Date()
    @State private var temperatureText = ""
    @State private var humidityText = ""
    @State private var lightText = ""

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var temperatureValue: Double? {
        guard let raw = CareInput.number(temperatureText) else { return nil }
        return unit == .metric ? raw : (raw - 32) * 5 / 9
    }

    private var humidityValue: Double? { CareInput.number(humidityText) }
    private var lightValue: Double? { CareInput.number(lightText) }

    private var temperatureValid: Bool {
        guard let temperatureValue else { return true }
        return (-20...60).contains(temperatureValue)
    }

    private var humidityValid: Bool {
        guard let humidityValue else { return true }
        return (0...100).contains(humidityValue)
    }

    private var canSave: Bool {
        (temperatureValue != nil || humidityValue != nil || lightValue != nil)
            && temperatureValid
            && humidityValid
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Log a reading")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("\(room.name) · targets follow the most advanced stage in the room.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                    }

                    HStack {
                        Text("When")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        DatePicker("", selection: $date)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .growCard(padding: 14)

                    targetCard

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Temperature (\(unit == .metric ? "°C" : "°F"))")
                        CareInput.field(
                            placeholder: unit == .metric ? "24.5" : "76.1",
                            text: $temperatureText,
                            keyboard: .decimalPad
                        )
                        if !temperatureValid {
                            CareInput.warning("Temperature is outside the range a grow room can plausibly be in.")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Relative humidity (%)")
                        CareInput.field(placeholder: "55", text: $humidityText, keyboard: .decimalPad)
                        if !humidityValid {
                            CareInput.warning("Humidity has to be between 0 and 100%.")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Light (PPFD)")
                        CareInput.field(placeholder: "450", text: $lightText, keyboard: .decimalPad)
                    }

                    PrimaryButton("Save reading", systemImage: "checkmark", isEnabled: canSave) {
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
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Target range")
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(Theme.secondaryInk)
            if let stage = room.dominantStage ?? .some(.veg) {
                if let temperature = stage.targetTemperatureC {
                    Text("Temperature \(Format.temperatureRange(temperature, unit: unit))")
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                if let humidity = stage.targetHumidityPercent {
                    Text("Humidity \(String(format: "%.0f–%.0f%%", humidity.lowerBound, humidity.upperBound))")
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Text(room.dominantStage == nil ? "No plants in this room, so the veg range is used." : "\(stage.title) stage")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
            }
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14)
    }

    private func save() {
        let reading = EnvironmentReading(
            date: date,
            temperatureC: temperatureValue,
            humidityPercent: humidityValue,
            lightPPFD: lightValue,
            source: .manual
        )
        context.insert(reading)
        reading.room = room
        EnvironmentAlertService.evaluate(reading: reading, room: room, context: context)

        if let reminder {
            CareLog.complete(reminder)
        }

        try? context.save()
        dismiss()
    }
}

enum CareInput {
    static func number(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    @ViewBuilder
    static func label(_ title: String) -> some View {
        Text(title)
            .font(Theme.sans(11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryInk)
    }

    static func field(placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .decimalPad) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .textFieldStyle(.plain)
            .font(Theme.sans(16))
            .foregroundStyle(Theme.ink)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surfaceSunken)
            )
    }

    static func warning(_ message: String) -> some View {
        Text(message)
            .font(Theme.sans(12))
            .foregroundStyle(Theme.amber)
            .fixedSize(horizontal: false, vertical: true)
    }
}
