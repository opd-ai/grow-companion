//
//  SharedGrowView.swift
//  Grow Companion
//
//  Read-only view of a decrypted grow share, plus the sheet that collects the
//  sender's share code before the file is opened.
//

import SwiftUI

struct OpenShareSheet: View {
    let data: Data

    @Environment(\.dismiss) private var dismiss
    @State private var senderCode = ""
    @State private var opened: GrowSharePayload?
    @State private var errorMessage: String?
    @State private var showingError = false

    private let service = SharePackageService()

    var body: some View {
        NavigationStack {
            Group {
                if let opened {
                    SharedGrowDetail(payload: opened) { dismiss() }
                } else {
                    codeEntry
                }
            }
            .background(Theme.background)
            .navigationTitle(opened == nil ? "Open a shared grow" : "Shared grow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .alert("Could not open this share", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var codeEntry: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Verify the sender")
                        .font(Theme.serif(26))
                        .foregroundStyle(Theme.ink)
                    Text("Paste the share code the sender sent you separately. It addresses the file and proves who created it, so the app can refuse a share that was altered or sent by someone else.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Sender's share code", text: $senderCode, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(3...5)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))
                        .accessibilityLabel("Sender share code")

                    if !senderCode.isEmpty && !ShareCode.isValid(senderCode) {
                        Text("That does not look like a share code.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.amber)
                    }
                }
                .growCard()

                PrimaryButton("Open shared grow", systemImage: "lock.open", isEnabled: ShareCode.isValid(senderCode)) {
                    open()
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func open() {
        do {
            opened = try service.openPackage(data, senderCode: senderCode)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct SharedGrowDetail: View {
    let payload: GrowSharePayload
    let onDone: () -> Void

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                notice
                if let compliance = payload.compliance {
                    complianceCard(compliance)
                }
                roomsCard
                plantsCard
                historyCard
                footer
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDone() }
                    .foregroundStyle(Theme.primary)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Read-only copy · \(payload.totalRecords) records")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        guard let name = payload.profile?.stateName, !name.isEmpty else { return "Shared grow" }
        return name
    }

    private var notice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.amber)
            Text("Shared \(Format.shortDate(payload.createdAt)) · expires \(Format.shortDate(payload.expiresAt)). Nothing here changes your own records.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(fill: Theme.amberSoft, padding: 14, radius: 16)
    }

    private func complianceCard(_ compliance: SharedCompliance) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Compliance estimate", subtitle: "\(compliance.jurisdictionCode) · pack \(compliance.rulePackVersion)")

            InfoRow(label: "Counted plants", value: "\(compliance.countedPlants) / \(compliance.plantLimit.map(String.init) ?? "—")")
            InfoRow(
                label: "Stored flower",
                value: "\(Format.weight(compliance.possessionGrams, unit: unit)) / \(Format.weightLimit(compliance.possessionLimitGrams, unit: unit))"
            )
            InfoRow(
                label: "Canopy",
                value: "\(Format.area(compliance.canopySquareMeters, unit: unit)) / \(Format.areaLimit(compliance.canopyLimitSquareMeters, unit: unit))"
            )
            InfoRow(label: "Status", value: compliance.status)

            Text("Rules last updated \(compliance.rulesUpdatedOn). \(compliance.notice)")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private var roomsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Rooms", subtitle: "\(payload.rooms.count) shared")
            if payload.rooms.isEmpty {
                Text("No room records were included.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                ForEach(payload.rooms, id: \.self) { room in
                    HStack(alignment: .firstTextBaseline) {
                        Text(room.name)
                            .font(Theme.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        Text(room.canopySquareMeters.map { Format.area($0, unit: unit) } ?? room.type)
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .growCard()
    }

    private var plantsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Plants", subtitle: "\(payload.plants.count) shared")
            if payload.plants.isEmpty {
                Text("No plant records were included.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                ForEach(payload.plants, id: \.self) { plant in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(plant.name)
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            Text(plant.stage)
                                .font(Theme.sans(12, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }
                        Text([plant.strain, plant.room].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.secondaryInk)

                        if let harvest = plant.harvest {
                            Text(harvestSummary(harvest))
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.tertiaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .growCard()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Care history", subtitle: "Read-only summary")
            InfoRow(label: "Environment readings", value: "\(payload.readings.count)")
            InfoRow(label: "Feed and watering events", value: "\(payload.feedEvents.count)")
            InfoRow(label: "Treatments", value: "\(payload.treatments.count)")
            InfoRow(label: "Scouting checks", value: "\(payload.scoutingChecks.count)")

            if let latest = payload.readings.last {
                Text("Latest reading \(Format.shortDate(latest.date)): \(temperatureSummary(latest))")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard()
    }

    private var footer: some View {
        Text("Only the categories the sender chose are here. Personal notes, the cultivation journal and the sender's county are not part of a share.")
            .font(Theme.sans(11))
            .foregroundStyle(Theme.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func harvestSummary(_ harvest: SharedHarvest) -> String {
        var parts: [String] = []
        if let dry = harvest.dryWeightGrams {
            parts.append("\(Format.weight(dry, unit: unit)) dry")
        }
        if let disposition = harvest.disposition {
            parts.append(disposition)
        }
        if let rating = harvest.rating {
            parts.append("\(rating) of 5")
        }
        return parts.joined(separator: " · ")
    }

    private func temperatureSummary(_ reading: SharedReading) -> String {
        var parts: [String] = []
        if let temperature = reading.temperatureC {
            parts.append(Format.temperature(temperature, unit: unit))
        }
        if let humidity = reading.humidityPercent {
            parts.append("\(Int(humidity.rounded()))% humidity")
        }
        if let ppfd = reading.lightPPFD {
            parts.append("\(Int(ppfd.rounded())) PPFD")
        }
        return parts.isEmpty ? "no measurements" : parts.joined(separator: " · ")
    }
}
