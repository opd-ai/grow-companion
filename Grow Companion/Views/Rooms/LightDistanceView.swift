//
//  LightDistanceView.swift
//  Grow Companion
//

import SwiftUI
import ARKit

struct LightDistanceView: View {
    @Bindable var room: Room

    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = LightDistanceScanner()
    @State private var fixture: LightFixtureType
    @State private var manualCentimeters = ""
    @State private var confirmedMeters: Double?
    @State private var showingManual = false

    init(room: Room) {
        self.room = room
        _fixture = State(initialValue: room.lightFixture)
    }

    private var stage: PlantStage { room.dominantStage ?? .veg }

    private var targetRange: ClosedRange<Double>? {
        guard let base = fixture.targetRangeMeters else { return nil }
        switch stage {
        case .seed, .clone:
            return (base.upperBound * 0.95)...(base.upperBound * 1.35)
        case .veg:
            return (base.lowerBound * 1.10)...(base.upperBound * 1.15)
        case .flower:
            return base
        default:
            return base
        }
    }

    private var candidateMeters: Double? {
        if let confirmedMeters { return confirmedMeters }
        guard let value = Double(manualCentimeters.replacingOccurrences(of: ",", with: ".")), value > 0 else { return scanner.distanceMeters }
        return value / 100
    }

    private var distanceStatus: String? {
        guard let distance = candidateMeters, let targetRange else { return nil }
        if targetRange.contains(distance) { return String(localized: "Inside the target range") }
        return distance < targetRange.lowerBound ? "Closer than the target range" : "Farther than the target range"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                fixtureCard
                measurementCard
                targetCard
                savedCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { scanner.start() }
        .onDisappear { scanner.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Measure light distance")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Confirm the distance from \(room.name)'s fixture to the canopy for the current \(stage.title.lowercased()) stage.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fixtureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Fixture", subtitle: "Targets are guidance, not a substitute for the fixture manual")
            Picker("Fixture type", selection: $fixture) {
                ForEach(LightFixtureType.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: fixture) { _, newValue in
                room.lightFixture = newValue
                try? room.modelContext?.save()
            }
        }
        .growCard()
    }

    private var measurementCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Canopy distance", subtitle: scanner.isSupported ? "LiDAR measurement is processed temporarily on this device" : "LiDAR is not available on this device")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(candidateMeters.map { String(format: "%.0f", $0 * 100) } ?? "—")
                    .font(Theme.serif(48))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text("cm")
                    .font(Theme.sans(16, weight: .semibold))
                    .foregroundStyle(Theme.secondaryInk)
                Spacer()
            }

            if let status = distanceStatus {
                Pill(
                    text: status,
                    systemImage: status == "Inside the target range" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    tint: status == "Inside the target range" ? Theme.primary : Theme.amber,
                    fill: status == "Inside the target range" ? Theme.sageSoft : Theme.amberSoft
                )
            }

            if scanner.isSupported {
                HStack(spacing: 8) {
                    Circle().fill(scanner.distanceMeters == nil ? Theme.amber : Theme.primary).frame(width: 8, height: 8)
                    Text(scanner.distanceMeters == nil ? "Point the camera at the canopy" : "Live LiDAR reading")
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryInk)
                }
            } else {
                manualEntry
            }

            HStack(spacing: 10) {
                SecondaryButton("Measure again", systemImage: "arrow.clockwise") {
                    confirmedMeters = nil
                    manualCentimeters = ""
                    scanner.start()
                }
                SecondaryButton("Enter manually", systemImage: "pencil") {
                    showingManual = true
                }
            }
        }
        .growCard()
        .sheet(isPresented: $showingManual) {
            manualSheet
        }
    }

    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            CareInput.label("Distance in centimetres")
            TextField("e.g. 45", text: $manualCentimeters)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var manualSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Enter the distance from the fixture to the highest canopy point.")
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.secondaryInk)
                CareInput.label("Centimetres")
                TextField("45", text: $manualCentimeters)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                PrimaryButton("Use this measurement", systemImage: "checkmark", isEnabled: candidateMeters != nil) {
                    confirmedMeters = candidateMeters
                    showingManual = false
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingManual = false }
                }
            }
        }
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Stage target", subtitle: stage.title)
            if let targetRange {
                Text(String(format: "%.0f–%.0f cm", targetRange.lowerBound * 100, targetRange.upperBound * 100))
                    .font(Theme.sans(21, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(fixture.guidanceSource)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No default target for this fixture.")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(fixture.guidanceSource)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
            }
        }
        .growCard(fill: Theme.surfaceSunken)
    }

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Saved on this room")
            if let distance = room.canopyDistanceMeters {
                InfoRow(label: "Last confirmed", value: String(format: "%.0f cm", distance * 100))
                if let date = room.canopyDistanceMeasuredAt {
                    InfoRow(label: "Measured", value: "\(Format.shortDate(date)) at \(Format.time(date))")
                }
                InfoRow(label: "Method", value: room.canopyDistanceSource == .lidar ? "LiDAR" : "Manual")
            } else {
                Text("No distance saved yet.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            }
            PrimaryButton("Confirm and save", systemImage: "checkmark", isEnabled: candidateMeters != nil) {
                save()
            }
        }
        .growCard()
    }

    private func save() {
        guard let distance = candidateMeters else { return }
        room.lightFixture = fixture
        room.canopyDistanceMeters = distance
        room.canopyDistanceMeasuredAt = Date()
        room.canopyDistanceSource = scanner.distanceMeters != nil && confirmedMeters == nil ? .lidar : .manual
        try? room.modelContext?.save()
    }
}
