//
//  AnomalyReviewView.swift
//  Grow Companion
//
//  Read-only review of unusual environment changes. It creates no alerts.
//

import SwiftUI
import SwiftData

struct AnomalyReviewView: View {
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var selectedRoomName = ""
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()

    private var selectedRoom: Room? { rooms.first { $0.name == selectedRoomName } }
    private var readings: [EnvironmentReading] {
        guard let selectedRoom else { return [] }
        return selectedRoom.environmentReadings
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date > $1.date }
    }

    private var temperatureValues: [Double] { readings.compactMap(\.temperatureC) }
    private var humidityValues: [Double] { readings.compactMap(\.humidityPercent) }
    private var temperatureBaseline: Double? { baseline(temperatureValues) }
    private var humidityBaseline: Double? { baseline(humidityValues) }
    private var temperatureSignals: [EnvironmentReading] {
        guard let baseline = temperatureBaseline else { return [] }
        return readings.filter { reading in
            guard let value = reading.temperatureC else { return false }
            return abs(value - baseline) >= 2
        }
    }
    private var humiditySignals: [EnvironmentReading] {
        guard let baseline = humidityBaseline else { return [] }
        return readings.filter { reading in
            guard let value = reading.humidityPercent else { return false }
            return abs(value - baseline) >= 10
        }
    }
    private var hasSparseData: Bool {
        temperatureValues.count < 6 && humidityValues.count < 6
    }
    private var hasSignal: Bool { !temperatureSignals.isEmpty || !humiditySignals.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                selectors
                statusCard
                if hasSignal { signalCard }
                readingsCard
                disclaimer
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedRoomName.isEmpty { selectedRoomName = rooms.first?.name ?? "" }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Environment anomalies")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Patterns to review, not diagnoses. This view reads existing records only.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectors: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Review range", subtitle: "Compare readings with this room's recent baseline")
            Picker("Room", selection: $selectedRoomName) {
                if rooms.isEmpty { Text("No rooms recorded").tag("") }
                ForEach(rooms) { room in Text(room.name).tag(room.name) }
            }
            .tint(Theme.primary)
            HStack {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
            }
            .font(Theme.sans(13))
            .tint(Theme.primary)
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14, radius: 16)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: hasSparseData ? "questionmark.circle.fill" : (hasSignal ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(hasSparseData ? Theme.secondaryInk : (hasSignal ? Theme.amber : Theme.primary))
                VStack(alignment: .leading, spacing: 3) {
                    Text(hasSparseData ? "Sparse data" : (hasSignal ? "Unusual shift to review" : "No unusual shifts found"))
                        .font(Theme.sans(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(statusDetail)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !readings.isEmpty {
                HStack(spacing: 14) {
                    value("Readings", "\(readings.count)")
                    value("Temp baseline", temperatureBaseline.map { String(format: "%.1f °C", $0) } ?? "Not enough data")
                    value("RH baseline", humidityBaseline.map { String(format: "%.0f%%", $0) } ?? "Not enough data")
                }
            }
        }
        .growCard(fill: hasSignal ? Theme.amberSoft : Theme.sageSoft)
    }

    private var statusDetail: String {
        if selectedRoom == nil { return String(localized: "Choose a room with readings to begin.") }
        if readings.isEmpty { return String(localized: "No readings were recorded in this range.") }
        if hasSparseData { return String(localized: "At least six readings for a metric are needed before a change is treated as a signal.") }
        if hasSignal { return String(localized: "The highlighted readings differ materially from the room's recent average. Review the records below; no alert was created.") }
        return String(localized: "Temperature and humidity stayed close to the room's recent average in this range.")
    }

    private func value(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Theme.sans(10, weight: .semibold)).foregroundStyle(Theme.tertiaryInk)
            Text(value).font(Theme.sans(12, weight: .semibold)).foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Contributing readings", subtitle: "The records that differ from the baseline")
            ForEach(Array(contributingReadings.prefix(12)), id: \.persistentModelID) { reading in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(Theme.amber)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Format.shortDate(reading.date) + " · " + Format.time(reading.date))
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(readingSummary(reading))
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.secondaryInk)
                        Text(reading.source == .sensor ? "Sensor-sourced" : "Manual entry")
                            .font(Theme.sans(10))
                            .foregroundStyle(Theme.tertiaryInk)
                    }
                    Spacer()
                }
                if reading.persistentModelID != contributingReadings.prefix(12).last?.persistentModelID {
                    Divider().overlay(Theme.hairline)
                }
            }
        }
        .growCard()
    }

    private var readingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Recent readings", subtitle: "Actual values only")
            if readings.isEmpty {
                Text("No readings to review.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                ForEach(Array(readings.prefix(8)), id: \.persistentModelID) { reading in
                    HStack {
                        Text(Format.shortDate(reading.date) + " · " + Format.time(reading.date))
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        Text(readingSummary(reading))
                            .font(Theme.sans(11, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14, radius: 16)
    }

    private var disclaimer: some View {
        Text("This report is read-only. It does not create alerts, change readings or recommend a treatment.")
            .font(Theme.sans(11))
            .foregroundStyle(Theme.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var contributingReadings: [EnvironmentReading] {
        Array(Set(temperatureSignals + humiditySignals)).sorted { $0.date > $1.date }
    }

    private func baseline(_ values: [Double]) -> Double? {
        guard values.count >= 6 else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func readingSummary(_ reading: EnvironmentReading) -> String {
        var values: [String] = []
        if let temperature = reading.temperatureC { values.append(String(format: "%.1f °C", temperature)) }
        if let humidity = reading.humidityPercent { values.append(String(format: "%.0f%% RH", humidity)) }
        return values.isEmpty ? "No temp or RH" : values.joined(separator: " · ")
    }
}
