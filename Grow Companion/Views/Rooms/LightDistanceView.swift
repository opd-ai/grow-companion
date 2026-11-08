//
//  LightDistanceView.swift
//  Grow Companion
//
//  Measures the distance from a room's fixture to the canopy and compares it
//  with the cited band for the room's stage. The manual path is complete, so a
//  device without LiDAR gets the same guidance.
//

import SwiftUI
import ARKit

struct LightDistanceView: View {
    @Bindable var room: Room

    @StateObject private var scanner = LightDistanceScanner()
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var fixture: LightFixtureType
    @State private var entry = ""
    @State private var confirmedMeters: Double?
    @State private var showingTargetEditor = false

    init(room: Room) {
        self.room = room
        _fixture = State(initialValue: room.lightFixture)
    }

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var stage: PlantStage { room.dominantStage ?? .veg }

    private var advice: LightDistanceAdvice? {
        LightDistanceService.advice(
            for: stage,
            fixture: fixture,
            userSetMeters: room.growerSetLightTargetRange
        )
    }

    private var typedMeters: Double? {
        Format.meters(fromEntry: entry, unit: unit)
    }

    private var measuredMeters: Double? {
        if let confirmedMeters { return confirmedMeters }
        if let typedMeters { return typedMeters }
        return scanner.distanceMeters
    }

    private var status: LightDistanceStatus {
        LightDistanceService.status(distance: measuredMeters, target: advice)
    }

    private var readingSource: LightDistanceSource {
        if confirmedMeters != nil || typedMeters != nil { return .manual }
        return scanner.distanceMeters == nil ? .manual : .lidar
    }

    private var reMeasureReason: LightDistanceReason? {
        guard let reason = room.lightDistanceReason else { return nil }
        if case .neverMeasured = reason { return nil }
        return reason
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                fixtureCard
                measurementCard
                targetCard
                reMeasureCard
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
        .sheet(isPresented: $showingTargetEditor) {
            LightTargetEditor(room: room, fixture: fixture, unit: unit)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Measure light distance")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text(String(localized: "Confirm the distance from \(room.name)'s fixture to the canopy for the current \(stage.title.lowercased()) stage."))
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fixtureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Fixture", subtitle: String(localized: "Targets are guidance, not a substitute for the fixture manual"))
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
            SectionHeader(
                "Canopy distance",
                subtitle: scanner.isSupported
                    ? String(localized: "LiDAR is read in memory and never saved")
                    : String(localized: "LiDAR is not available on this device, so type the distance")
            )

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(measuredMeters.map { Format.distance($0, unit: unit) } ?? "—")
                    .font(Theme.serif(44))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Pill(
                    text: LightDistanceService.statusTitle(status),
                    systemImage: status.systemImage,
                    tint: status.tint,
                    fill: status.fillTint
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                measuredMeters.map {
                    String(localized: "Measured \(Format.distance($0, unit: unit)), \(LightDistanceService.statusTitle(status))")
                } ?? String(localized: "No distance entered yet")
            )

            if scanner.isSupported {
                HStack(spacing: 8) {
                    Circle()
                        .fill(scanner.distanceMeters == nil ? Theme.amber : Theme.primary)
                        .frame(width: 8, height: 8)
                    Text(scanner.distanceMeters == nil
                        ? String(localized: "Point the camera at the canopy")
                        : String(localized: "Live LiDAR reading"))
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryInk)
                }
                .accessibilityElement(children: .combine)
            }

            manualEntry

            if scanner.isSupported, scanner.distanceMeters != nil, !entry.isEmpty {
                SecondaryButton("Use the live reading", systemImage: "ruler") {
                    entry = ""
                    confirmedMeters = nil
                }
            }

            SecondaryButton("Clear and measure again", systemImage: "arrow.clockwise") {
                confirmedMeters = nil
                entry = ""
                scanner.start()
            }
        }
        .growCard()
    }

    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            CareInput.label(String(localized: "Distance in \(Format.distanceUnit(unit))"))
            CareInput.field(placeholder: unit == .metric ? "45" : "18", text: $entry)
            Text("Type the distance from the fixture to the highest canopy point. It is stored as your confirmed reading.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Stage target", subtitle: stage.title)
            if let advice {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.distanceRange(advice.range, unit: unit))
                        .font(Theme.sans(21, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    if advice.isUserSet {
                        Pill(
                            text: String(localized: "Your target"),
                            systemImage: "person.crop.circle",
                            tint: Theme.primary,
                            fill: Theme.sageSoft
                        )
                    }
                }
                Text(advice.summary)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(advice.detail)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                if !advice.isUserSet {
                    InfoRow(
                        label: String(localized: "Reviewed"),
                        value: Format.shortDate(LightDistanceService.reviewDate)
                    )
                }
            } else {
                Text("No default target for this fixture. Set your own from the manual.")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                    .fixedSize(horizontal: false, vertical: true)
                Text(fixture.guidanceSource)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SecondaryButton(
                advice?.isUserSet == true
                    ? String(localized: "Edit your target")
                    : String(localized: "Set your own target"),
                systemImage: "slider.horizontal.3"
            ) {
                showingTargetEditor = true
            }
        }
        .growCard(fill: Theme.surfaceSunken)
    }

    @ViewBuilder
    private var reMeasureCard: some View {
        if let reason = reMeasureReason {
            VStack(alignment: .leading, spacing: 8) {
                Pill(
                    text: LightDistanceService.reMeasureTitle(reason),
                    systemImage: "ruler",
                    tint: Theme.amber,
                    fill: Theme.amberSoft
                )
                Text(LightDistanceService.reMeasureDetail(reason))
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .growCard(padding: 16)
            .accessibilityElement(children: .combine)
        }
    }

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Saved on this room")
            if let distance = room.canopyDistanceMeters {
                InfoRow(
                    label: String(localized: "Last confirmed"),
                    value: Format.distance(distance, unit: unit)
                )
                if let date = room.canopyDistanceMeasuredAt {
                    InfoRow(
                        label: String(localized: "Measured"),
                        value: "\(Format.shortDate(date)) · \(Format.time(date))"
                    )
                }
                if let savedStage = room.canopyDistanceStage {
                    InfoRow(label: String(localized: "Stage at reading"), value: savedStage.title)
                }
                InfoRow(
                    label: String(localized: "Method"),
                    value: room.canopyDistanceSource == .lidar
                        ? String(localized: "LiDAR")
                        : String(localized: "Manual")
                )
            } else {
                Text("No distance saved yet.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            }
            PrimaryButton("Confirm and save", systemImage: "checkmark", isEnabled: measuredMeters != nil) {
                save()
            }
        }
        .growCard()
    }

    private func save() {
        guard let distance = measuredMeters else { return }
        room.lightFixture = fixture
        room.canopyDistanceMeters = distance
        room.canopyDistanceMeasuredAt = Date()
        room.canopyDistanceStage = room.dominantStage
        room.canopyDistanceSource = readingSource
        try? room.modelContext?.save()
    }
}

// MARK: - Target editor

private struct LightTargetEditor: View {
    @Bindable var room: Room

    let fixture: LightFixtureType
    let unit: UnitSystem

    @Environment(\.dismiss) private var dismiss

    @State private var lowerEntry = ""
    @State private var upperEntry = ""

    private var lowerMeters: Double? { Format.meters(fromEntry: lowerEntry, unit: unit) }
    private var upperMeters: Double? { Format.meters(fromEntry: upperEntry, unit: unit) }

    private var isValid: Bool {
        guard let lowerMeters, let upperMeters else { return false }
        return lowerMeters < upperMeters
    }

    private var showsOrderError: Bool {
        guard let lowerMeters, let upperMeters else { return false }
        return lowerMeters >= upperMeters
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("A target you set replaces the app's figure for this room. Use the distance in your fixture manual; the app does not verify it.")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label(String(localized: "Lower bound in \(Format.distanceUnit(unit))"))
                        CareInput.field(placeholder: unit == .metric ? "30" : "12", text: $lowerEntry)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label(String(localized: "Upper bound in \(Format.distanceUnit(unit))"))
                        CareInput.field(placeholder: unit == .metric ? "60" : "24", text: $upperEntry)
                    }

                    if showsOrderError {
                        CareInput.warning(String(localized: "The lower bound has to be smaller than the upper bound."))
                    }

                    PrimaryButton("Save target", systemImage: "checkmark", isEnabled: isValid) {
                        guard let lowerMeters, let upperMeters else { return }
                        room.growerSetLightTargetRange = lowerMeters...upperMeters
                        try? room.modelContext?.save()
                        dismiss()
                    }

                    if room.hasGrowerSetLightTarget {
                        SecondaryButton("Use the app guidance", systemImage: "arrow.uturn.backward") {
                            room.growerSetLightTargetRange = nil
                            try? room.modelContext?.save()
                            dismiss()
                        }
                    }

                    Text("Saved on this device only. Nothing is uploaded.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Your target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        let startingRange = room.growerSetLightTargetRange
            ?? LightDistanceService.band(for: room.dominantStage ?? .veg, fixture: fixture)
        guard let startingRange else { return }
        lowerEntry = Format.distanceEntryText(startingRange.lowerBound, unit: unit)
        upperEntry = Format.distanceEntryText(startingRange.upperBound, unit: unit)
    }
}

// MARK: - Status presentation

private extension LightDistanceStatus {
    var systemImage: String {
        switch self {
        case .inside: return "checkmark.circle.fill"
        case .closer, .over: return "exclamationmark.triangle.fill"
        case .noTarget: return "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .inside: return Theme.primary
        case .closer, .over: return Theme.amber
        case .noTarget: return Theme.secondaryInk
        }
    }

    var fillTint: Color {
        switch self {
        case .inside: return Theme.sageSoft
        case .closer, .over: return Theme.amberSoft
        case .noTarget: return Theme.surfaceSunken
        }
    }
}
