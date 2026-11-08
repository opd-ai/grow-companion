//
//  GrowCalculatorsView.swift
//  Grow Companion
//
//  Read-only VPD, DLI and dosing calculators.
//

import SwiftUI
import SwiftData

struct GrowCalculatorsView: View {
    @Query(sort: \Room.name) private var rooms: [Room]
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var selectedRoomName = ""
    @State private var calculator: Calculator = .vpd
    @State private var volumeText = ""
    @State private var doseText = ""

    private enum Calculator: String, CaseIterable, Identifiable {
        case vpd, dli, dosing
        var id: String { rawValue }
        var title: String { rawValue.uppercased() }
    }

    private var room: Room? { rooms.first { $0.name == selectedRoomName } }
    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }
    private var latestReading: EnvironmentReading? { room?.environmentReadings.sorted { $0.date > $1.date }.first }
    private var volume: Double? { Double(volumeText.replacingOccurrences(of: ",", with: ".")) }
    private var dose: Double? { Double(doseText.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                roomPicker
                Picker("Calculator", selection: $calculator) {
                    ForEach(Calculator.allCases) { option in Text(option.title).tag(option) }
                }
                .pickerStyle(.segmented)
                .tint(Theme.primary)
                calculatorCard
                formulaCard
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Grow calculators")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedRoomName.isEmpty { selectedRoomName = rooms.first?.name ?? "" }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Grow calculators").font(Theme.serif(30)).foregroundStyle(Theme.ink)
            Text("Useful numbers, plainly explained.").font(Theme.sans(15)).foregroundStyle(Theme.secondaryInk)
        }
    }

    private var roomPicker: some View {
        HStack {
            Text("Room").font(Theme.sans(14)).foregroundStyle(Theme.secondaryInk)
            Spacer()
            Picker("Room", selection: $selectedRoomName) {
                ForEach(rooms) { room in Text(room.name).tag(room.name) }
            }
            .labelsHidden()
            .tint(Theme.primary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))
    }

    @ViewBuilder
    private var calculatorCard: some View {
        switch calculator {
        case .vpd: vpdCard
        case .dli: dliCard
        case .dosing: dosingCard
        }
    }

    private var vpdCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("VPD", subtitle: "Vapour pressure deficit")
            inputRow("Temperature", value: latestReading?.temperatureC.map { Format.temperature($0, unit: unit) } ?? "Missing")
            inputRow("Relative humidity", value: latestReading?.humidityPercent.map { String(format: "%.0f%%", $0) } ?? "Missing")
            resultRow(title: "VPD", value: vpdValue)
            if latestReading == nil { missingMessage("Log a temperature and humidity reading for this room to calculate VPD.") }
        }
        .growCard()
    }

    private var dliCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("DLI", subtitle: "Daily light integral")
            inputRow("PPFD", value: latestReading?.lightPPFD.map { String(format: "%.0f μmol/m²/s", $0) } ?? "Missing")
            inputRow("Light schedule", value: room.map { String(format: "%.1f hours/day", $0.lightHoursPerDay) } ?? "Missing")
            resultRow(title: "DLI", value: dliValue)
            if latestReading?.lightPPFD == nil { missingMessage("Log a PPFD reading for this room to calculate DLI.") }
        }
        .growCard()
    }

    private var dosingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Dosing", subtitle: "Volume × dose per litre")
            inputField("Volume", placeholder: "e.g. 10", suffix: "L", text: $volumeText)
            inputField("Dose per litre", placeholder: "e.g. 2", suffix: "mL/L", text: $doseText)
            if let volume, let dose {
                resultRow(title: "Total product", value: String(format: "%.2f mL", volume * dose))
            } else {
                resultRow(title: "Total product", value: "Missing inputs")
            }
            inputRow("Room target pH", value: room?.feedTargetPH.map { String(format: "%.2f", $0) } ?? "Not set")
            inputRow("Room target EC", value: room?.feedTargetEC.map { String(format: "%.2f", $0) } ?? "Not set")
        }
        .growCard()
    }

    private var vpdValue: String {
        guard let temperature = latestReading?.temperatureC, let humidity = latestReading?.humidityPercent else { return "Missing inputs" }
        let saturation = 0.6108 * exp((17.27 * temperature) / (temperature + 237.3))
        let vpd = saturation * (1 - humidity / 100)
        return String(format: "%.2f kPa", vpd)
    }

    private var dliValue: String {
        guard let ppfd = latestReading?.lightPPFD, let room else { return "Missing inputs" }
        let dli = ppfd * room.lightHoursPerDay * 3600 / 1_000_000
        return String(format: "%.2f mol/m²/day", dli)
    }

    private func inputRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(Theme.sans(14)).foregroundStyle(Theme.secondaryInk)
            Spacer()
            Text(value).font(Theme.sans(14, weight: .semibold)).foregroundStyle(value == "Missing" || value == "Not set" ? Theme.tertiaryInk : Theme.ink)
        }
    }

    private func inputField(_ title: String, placeholder: String, suffix: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).font(Theme.sans(14)).foregroundStyle(Theme.secondaryInk)
            Spacer()
            TextField(placeholder, text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
            Text(suffix).font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk)
        }
    }

    private func resultRow(title: String, value: String) -> some View {
        HStack {
            Text(title).font(Theme.sans(16, weight: .semibold)).foregroundStyle(Theme.onHero)
            Spacer()
            Text(value).font(Theme.serif(24)).foregroundStyle(Theme.onHero)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.primary))
    }

    private func missingMessage(_ text: String) -> some View {
        Text(text).font(Theme.sans(12)).foregroundStyle(Theme.tertiaryInk).fixedSize(horizontal: false, vertical: true)
    }

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionHeader("Formula context")
            Group {
                switch calculator {
                case .vpd:
                    Text("VPD = saturation vapour pressure × (1 − relative humidity). Temperature and humidity come from the latest room reading.")
                case .dli:
                    Text("DLI = PPFD × light hours × 3,600 ÷ 1,000,000. It uses the room's recorded light schedule and latest PPFD reading.")
                case .dosing:
                    Text("Total product = volume × dose per litre. Room pH and EC targets are shown for reference only and are not inferred into the result.")
                }
            }
            .font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk).fixedSize(horizontal: false, vertical: true)
            Text("Calculations are read-only and create no grow records.")
                .font(Theme.sans(11)).foregroundStyle(Theme.tertiaryInk)
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14)
    }
}
