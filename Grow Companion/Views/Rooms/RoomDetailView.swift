//
//  RoomDetailView.swift
//  Grow Companion
//
//  The room dashboard: what is in the room, the canopy it contributes, the
//  photoperiod with a live countdown, and the schedule override log.
//

import SwiftUI
import SwiftData

struct RoomDetailView: View {
    @Bindable var room: Room

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journal: [JournalEntry]
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8

    @State private var showingEdit = false
    @State private var showingSchedule = false
    @State private var showingAddPlant = false
    @State private var showingDelete = false
    @State private var showingTreatmentEditor = false
    @State private var editingTreatment: Treatment?
    @State private var showingLightDistance = false
    @State private var showingPhotos = false

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }
    private var rule: JurisdictionRule? { profiles.first?.rule }

    private var roomPlants: [Plant] {
        room.plants.sorted { $0.plantedAt > $1.plantedAt }
    }

    private var report: ComplianceReport? {
        guard let rule else { return nil }
        return ComplianceEngine.report(
            plants: room.plants,
            rooms: [room],
            rule: rule,
            warningThreshold: warningThreshold
        )
    }

    private var photos: [PlantPhoto] {
        let entries = journal.filter { entry in
            entry.room?.persistentModelID == room.persistentModelID
                || entry.plant?.room?.persistentModelID == room.persistentModelID
        }
        return PhotoTimelineService.photos(from: entries)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                if !photos.isEmpty { photoTimelineCard }
                scheduleCard
                lightDistanceCard
                complianceCard
                RoomEnvironmentSection(room: room)
                EnvironmentAlertSection(room: room)
                RoomFeedScheduleSection(room: room)
                RoomFeedingSection(room: room)
                RoomCalibrationSection(room: room)
                RoomRemindersSection(room: room)
                ScoutingCheckSection(plant: nil, room: room)
                treatmentsSection
                plantsSection
                overrideLogSection
                deleteButton
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .sheet(isPresented: $showingEdit) {
            RoomEditorView(room: room)
        }
        .sheet(isPresented: $showingSchedule) {
            LightScheduleEditor(room: room)
        }
        .sheet(isPresented: $showingLightDistance) {
            NavigationStack {
                LightDistanceView(room: room)
            }
        }
        .sheet(isPresented: $showingPhotos) {
            PhotoTimelineView(title: room.name, photos: photos)
        }
        .sheet(isPresented: $showingAddPlant) {
            AddPlantView(preselectedRoom: room)
        }
        .sheet(isPresented: $showingTreatmentEditor) {
            TreatmentEditor(plant: nil, room: room)
        }
        .sheet(item: $editingTreatment) { treatment in
            TreatmentEditor(plant: nil, room: room, treatment: treatment)
        }
        .confirmationDialog(
            "Delete this room?",
            isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete room", role: .destructive) {
                deleteRoom()
            }
            Button("Keep room", role: .cancel) {}
        } message: {
            Text("Its plants are kept and lose their room assignment. The schedule history is deleted.")
        }
    }

    private var photoTimelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                "Photos",
                subtitle: "\(photos.count) photo\(photos.count == 1 ? "" : "s") in date order"
            )
            PhotoTimelineStrip(photos: photos) { _ in
                showingPhotos = true
            }
            SecondaryButton("Compare photos", systemImage: "rectangle.split.2x1") {
                showingPhotos = true
            }
        }
        .growCard(padding: 16)
    }

    private var lightDistanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Canopy distance", subtitle: room.canopyDistanceMeters.map { String(format: "Last confirmed %.0f cm", $0 * 100) } ?? "Not measured yet")
            if let date = room.canopyDistanceMeasuredAt {
                Text("Measured \(Format.shortDate(date)) · \(room.canopyDistanceSource == .lidar ? "LiDAR" : "manual")")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
            }
            SecondaryButton("Measure light distance", systemImage: "ruler") {
                showingLightDistance = true
            }
        }
        .growCard(fill: Theme.surfaceSunken)
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(room.name)
                        .font(Theme.serif(28))
                        .foregroundStyle(Theme.ink)
                    Text("\(room.type.title) · \(room.placementLabel)")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                }
                Spacer()
                Pill(
                    text: room.placementLabel,
                    systemImage: room.isIndoor ? "house" : "sun.max",
                    tint: Theme.primary,
                    fill: Theme.sageSoft
                )
            }

            HStack(spacing: 8) {
                InfoChip(
                    symbol: "lightbulb",
                    text: room.lightType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "No light recorded"
                        : room.lightType
                )
                if room.lightWatts > 0 {
                    InfoChip(symbol: "bolt", text: "\(room.lightWatts) W")
                }
                if let canopy = room.canopySquareMeters {
                    InfoChip(symbol: "square.dashed", text: Format.area(canopy, unit: unit))
                }
            }

            Divider().overlay(Theme.hairline)

            HStack(spacing: 16) {
                metric("Plants", "\(room.plants.count)")
                metric("Counted", "\(report?.countedPlants ?? 0)")
                metric("Flowering", "\(room.floweringPlantCount)")
            }

            SecondaryButton("Edit room details", systemImage: "square.and.pencil") {
                showingEdit = true
            }
        }
        .growCard()
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(Theme.tertiaryInk)
            Text(value)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Schedule

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Light schedule", subtitle: room.lightScheduleSummary)

            HStack(spacing: 10) {
                scheduleTimeBlock("On", minutes: room.lightsOnMinutes)
                scheduleTimeBlock("Off", minutes: room.lightsOffMinutes)
            }

            LiveScheduleStatus(room: room)

            if room.hasFloweringPlants {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    Text("\(room.floweringPlantCount) plant\(room.floweringPlantCount == 1 ? "" : "s") in this room are flowering. Any schedule change asks you to confirm first.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.amberSoft)
                )
            }

            SecondaryButton("Change schedule", systemImage: "clock.arrow.circlepath") {
                showingSchedule = true
            }
        }
        .growCard()
    }

    private func scheduleTimeBlock(_ title: String, minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(Theme.secondaryInk)
            Text(LightSchedule.timeLabel(minutes))
                .font(Theme.sans(18, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surfaceSunken)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Compliance

    private var complianceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Compliance contribution", subtitle: "What this room adds to your limits")

            if let report, let rule {
                complianceRow(
                    "Counted plants",
                    value: "\(report.countedPlants) / \(report.plantLimit.map(String.init) ?? "—")",
                    level: report.plantLevel
                )
                Divider().overlay(Theme.hairline)
                complianceRow(
                    "Canopy recorded",
                    value: report.canopyLimitSqM == nil
                        ? Format.area(report.canopySqM, unit: unit)
                        : "\(Format.area(report.canopySqM, unit: unit)) / \(Format.areaLimit(report.canopyLimitSqM, unit: unit))",
                    level: report.canopyLevel
                )
                if !rule.countingNote.isEmpty {
                    Text(rule.countingNote)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Choose a jurisdiction in the Rules tab to see how this room counts toward your limits.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard(padding: 16)
    }

    private func complianceRow(_ title: String, value: String, level: ComplianceLevel) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Pill(text: level.title, systemImage: level.symbolName, tint: level.tint, fill: level.softFill)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Treatments

    private var treatmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Room treatments", subtitle: room.treatments.isEmpty ? "No treatments recorded" : "\(room.treatments.count) record\(room.treatments.count == 1 ? "" : "s")")
            if room.treatments.isEmpty {
                Text("Record a treatment applied to the whole room. The app keeps what you applied and does not recommend products.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(room.treatments.sorted { $0.date > $1.date }) { treatment in
                        Button { editingTreatment = treatment } label: {
                            roomTreatmentRow(treatment)
                        }
                        .buttonStyle(.plain)
                        if treatment.id != room.treatments.sorted(by: { $0.date > $1.date }).last?.id { Divider().overlay(Theme.hairline) }
                    }
                }
                .growCard(padding: 14)
            }
            SecondaryButton("Log room treatment", systemImage: "plus") { showingTreatmentEditor = true }
        }
    }

    private func roomTreatmentRow(_ treatment: Treatment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: treatment.isWithdrawalActive ? "flag.fill" : "spraycan")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(treatment.isWithdrawalActive ? Theme.amber : Theme.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(treatment.productName).font(Theme.sans(14, weight: .semibold)).foregroundStyle(Theme.ink)
                Text([treatment.dose, Format.shortDate(treatment.date)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                if let endDate = treatment.withdrawalEndDate {
                    Text("Withdrawal ends \(Format.shortDate(endDate))").font(Theme.sans(12)).foregroundStyle(treatment.isWithdrawalActive ? Theme.amber : Theme.tertiaryInk)
                }
                if !treatment.note.isEmpty { Text(treatment.note).font(Theme.sans(12)).foregroundStyle(Theme.tertiaryInk).lineLimit(2) }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: Plants

    private var plantsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Plants in this room", subtitle: roomPlants.isEmpty ? "None yet" : "\(roomPlants.count)")

            if roomPlants.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("This room is empty")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Add a plant here to start tracking this space.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton("Add a plant", systemImage: "plus") {
                        showingAddPlant = true
                    }
                }
                .growCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(roomPlants) { plant in
                        NavigationLink {
                            PlantDetailView(plant: plant)
                        } label: {
                            PlantRow(plant: plant, showsTraining: true)
                        }
                        .buttonStyle(.plain)

                        if plant.id != roomPlants.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)

                SecondaryButton("Add a plant", systemImage: "plus") {
                    showingAddPlant = true
                }
            }
        }
    }

    // MARK: Override log

    private var overrideLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                "Schedule changes",
                subtitle: room.sortedLightEvents.isEmpty
                    ? "No changes recorded"
                    : "\(room.sortedLightEvents.count) manual change\(room.sortedLightEvents.count == 1 ? "" : "s")"
            )

            if room.sortedLightEvents.isEmpty {
                Text("Every manual change to this room's photoperiod is recorded here.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard(padding: 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(room.sortedLightEvents) { event in
                        LightScheduleEventRow(event: event)
                        if event.id != room.sortedLightEvents.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }
        }
    }

    private var deleteButton: some View {
        Button {
            showingDelete = true
        } label: {
            Text("Delete this room")
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func deleteRoom() {
        context.delete(room)
        try? context.save()
        dismiss()
    }
}

// MARK: - Live countdown

private struct LiveScheduleStatus: View {
    let room: Room

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            ScheduleStatusContent(
                lightsOnMinutes: room.lightsOnMinutes,
                lightsOffMinutes: room.lightsOffMinutes,
                now: timeline.date
            )
        }
    }
}

private struct ScheduleStatusContent: View {
    let lightsOnMinutes: Int
    let lightsOffMinutes: Int
    let now: Date

    var body: some View {
        let isOn = LightSchedule.isOn(
            on: lightsOnMinutes,
            off: lightsOffMinutes,
            at: now
        )
        let next = LightSchedule.nextSwitch(
            on: lightsOnMinutes,
            off: lightsOffMinutes,
            from: now
        )

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isOn ? "lightbulb.fill" : "moon.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(isOn ? "Lights are on" : "Lights are off")
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                if let next {
                    Text("\(next.isTurningOn ? "Turns on" : "Turns off") in \(LightSchedule.countdown(from: now, to: next.date)) · \(LightSchedule.timeLabel(next.isTurningOn ? lightsOnMinutes : lightsOffMinutes))")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.sageSoft)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Event row

private struct LightScheduleEventRow: View {
    let event: LightScheduleEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceSunken)
                    .frame(width: 32, height: 32)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(event.newSummary)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Was \(event.previousTimes) · now \(event.newTimes)")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                if event.hadFloweringPlants {
                    Pill(
                        text: "Changed during flower",
                        systemImage: "exclamationmark.triangle",
                        tint: Theme.amber,
                        fill: Theme.amberSoft
                    )
                }
                if !event.note.isEmpty {
                    Text(event.note)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            Text(Format.shortDate(event.date))
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}
