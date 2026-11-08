//
//  DryingCheckSheet.swift
//  Grow Companion
//
//  A daily drying or curing check: humidity, temperature, stem snap and a note,
//  with the mold-risk warning and its action checklist as you type.
//

import SwiftUI
import SwiftData

struct DryingCheckSheet: View {
    let session: DryingSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var humidityText = ""
    @State private var temperatureText = ""
    @State private var stemSnap: StemSnap = .bends
    @State private var note = ""

    private var isCuring: Bool { session.phase == .curing }

    private var humidity: Double? { CareInput.number(humidityText) }
    private var temperature: Double? { CareInput.number(temperatureText) }

    private var humidityValid: Bool {
        guard let humidity else { return true }
        return (0...100).contains(humidity)
    }

    private var canSave: Bool {
        (humidity != nil || temperature != nil) && humidityValid
    }

    private var risk: DryingRisk? {
        HarvestLog.risk(session: session, humidity: humidity, temperature: temperature)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isCuring ? "Log a curing check" : "Log today's check")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text(isCuring
                             ? "Jar humidity to aim for: \(humidityTargetText)."
                             : "Drying targets: \(humidityTargetText) and \(temperatureTargetText).")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Humidity (%)")
                        CareInput.field(placeholder: "60", text: $humidityText)
                        if !humidityValid {
                            CareInput.warning("Humidity has to be between 0 and 100%.")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Temperature (°C)")
                        CareInput.field(placeholder: "19.4", text: $temperatureText)
                    }

                    if !isCuring {
                        VStack(alignment: .leading, spacing: 8) {
                            CareInput.label("Stem snap")
                            Picker("Stem snap", selection: $stemSnap) {
                                ForEach(StemSnap.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text(stemSnap.detail)
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.tertiaryInk)
                        }
                    }

                    if let risk {
                        riskCard(risk)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Note (optional)")
                        TextField("Anything worth remembering", text: $note, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2...4)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.surfaceSunken)
                            )
                    }

                    PrimaryButton("Save check", systemImage: "checkmark", isEnabled: canSave) {
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

    private func riskCard(_ risk: DryingRisk) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(risk.isCritical ? Theme.danger : Theme.amber)
                Text(risk.title)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text(risk.message)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(risk.checklist.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryInk)
                    Text(item)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .growCard(fill: risk.isCritical ? Theme.dangerSoft : Theme.amberSoft, padding: 14)
    }

    private var humidityTargetText: String {
        let range = isCuring ? session.curingHumidityRange : session.targetHumidityRange
        return String(format: "%.0f–%.0f%%", range.lowerBound, range.upperBound)
    }

    private var temperatureTargetText: String {
        let range = session.targetTemperatureRange
        return String(format: "%.0f–%.0f °C", range.lowerBound, range.upperBound)
    }

    private func save() {
        let check = DryingCheck(
            date: Date(),
            humidityPercent: humidity,
            temperatureC: temperature,
            stemSnap: isCuring ? nil : stemSnap,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(check)
        check.session = session
        try? context.save()
        dismiss()
    }
}
