//
//  GardenTimelineView.swift
//  Grow Companion
//
//  One chronological, read-only view of everything that happened in the
//  garden: stage moves, journal entries, feeds, readings, calibrations, light
//  changes, training, treatments, scouting and drying or curing checks.
//

import SwiftUI
import SwiftData

struct GardenTimelineView: View {
    @Query(sort: \StageEvent.date, order: .reverse) private var stageEvents: [StageEvent]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journal: [JournalEntry]
    @Query(sort: \FeedEvent.date, order: .reverse) private var feeds: [FeedEvent]
    @Query(sort: \EnvironmentReading.date, order: .reverse) private var readings: [EnvironmentReading]
    @Query(sort: \CalibrationEvent.date, order: .reverse) private var calibrations: [CalibrationEvent]
    @Query(sort: \LightScheduleEvent.date, order: .reverse) private var lightEvents: [LightScheduleEvent]
    @Query(sort: \TrainingSession.date, order: .reverse) private var training: [TrainingSession]
    @Query(sort: \Treatment.date, order: .reverse) private var treatments: [Treatment]
    @Query(sort: \ScoutingCheck.date, order: .reverse) private var scouting: [ScoutingCheck]
    @Query(sort: \DryingCheck.date, order: .reverse) private var dryingChecks: [DryingCheck]
    @Query(sort: \CureBurp.date, order: .reverse) private var cureBurps: [CureBurp]
    @Query(sort: \EnvironmentAlert.detectedAt, order: .reverse) private var environmentAlerts: [EnvironmentAlert]

    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var selectedRoom: Room?
    @State private var selectedPlant: Plant?
    @State private var selectedKinds: Set<GardenEventKind> = Set(GardenEventKind.allCases)

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var filter: GardenTimelineFilter {
        GardenTimelineFilter(
            roomID: selectedRoom?.persistentModelID,
            plantID: selectedPlant?.persistentModelID,
            kinds: selectedKinds
        )
    }

    private var allEvents: [GardenEvent] {
        GardenTimelineService.events(
            from: GardenTimelineSources(
                stageEvents: stageEvents,
                journal: journal,
                feeds: feeds,
                readings: readings,
                calibrations: calibrations,
                lightEvents: lightEvents,
                training: training,
                treatments: treatments,
                scouting: scouting,
                dryingChecks: dryingChecks,
                cureBurps: cureBurps,
                environmentAlerts: environmentAlerts
            ),
            unit: unit
        )
    }

    private var events: [GardenEvent] {
        let currentFilter = filter
        return allEvents.filter { currentFilter.matches($0) }
    }

    private var sections: [DaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { day in
            DaySection(id: day, events: grouped[day] ?? [])
        }
    }

    private var plantsForFilter: [Plant] {
        guard let selectedRoom else { return plants }
        return plants.filter { $0.room?.persistentModelID == selectedRoom.persistentModelID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !rooms.isEmpty {
                    RoomFilterChips(rooms: rooms, selectedRoom: $selectedRoom)
                }

                filterRow

                if events.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(dayTitle(section.id))
                                ForEach(section.events) { event in
                                    row(for: event)
                                }
                            }
                        }
                    }
                }

                footnote
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Garden timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onChange(of: selectedRoom) { _, newRoom in
            guard let plant = selectedPlant else { return }
            if let newRoom, plant.room?.persistentModelID != newRoom.persistentModelID {
                selectedPlant = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Everything in one place")
                .font(Theme.serif(28))
                .foregroundStyle(Theme.ink)
            Text("\(events.count) record\(events.count == 1 ? "" : "s") in date order. This view only reads your records; it never changes them.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            Menu {
                Button("All plants") { selectedPlant = nil }
                ForEach(plantsForFilter) { plant in
                    Button(plant.displayName) { selectedPlant = plant }
                }
            } label: {
                filterChip(
                    title: selectedPlant?.displayName ?? "All plants",
                    symbol: "leaf",
                    isSet: selectedPlant != nil
                )
            }

            Menu {
                Button("All types") { selectedKinds = Set(GardenEventKind.allCases) }
                Divider()
                ForEach(GardenEventKind.allCases) { kind in
                    Button {
                        toggle(kind)
                    } label: {
                        Label(
                            kind.title,
                            systemImage: selectedKinds.contains(kind) ? "checkmark" : kind.systemImage
                        )
                    }
                }
            } label: {
                filterChip(
                    title: selectedKinds.count == GardenEventKind.allCases.count
                        ? "All types"
                        : "\(selectedKinds.count) type\(selectedKinds.count == 1 ? "" : "s")",
                    symbol: "line.3.horizontal.decrease",
                    isSet: selectedKinds.count != GardenEventKind.allCases.count
                )
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    private func filterChip(title: String, symbol: String, isSet: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(Theme.sans(13, weight: .semibold))
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(isSet ? Theme.primary : Theme.secondaryInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(isSet ? Theme.sageSoft : Theme.surfaceSunken))
    }

    @ViewBuilder
    private func row(for event: GardenEvent) -> some View {
        if event.hasDestination {
            NavigationLink {
                destination(for: event)
            } label: {
                rowContent(event)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(event)
        }
    }

    private func rowContent(_ event: GardenEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sageSoft)
                    .frame(width: 34, height: 34)
                Image(systemName: event.kind.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.kind.title)
                        .font(Theme.sans(10, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.0)
                        .foregroundStyle(Theme.secondaryInk)
                    Spacer(minLength: 8)
                    Text(Format.time(event.date))
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                }

                Text(event.title)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = event.detail {
                    Text(detail)
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if event.plantName != nil || event.roomName != nil {
                    HStack(spacing: 6) {
                        if let plantName = event.plantName {
                            Pill(
                                text: plantName,
                                systemImage: "leaf",
                                tint: Theme.secondaryInk,
                                fill: Theme.surfaceSunken
                            )
                        }
                        if let roomName = event.roomName {
                            Pill(
                                text: roomName,
                                systemImage: "tent",
                                tint: Theme.secondaryInk,
                                fill: Theme.surfaceSunken
                            )
                        }
                    }
                }
            }

            if event.hasDestination {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryInk)
                    .padding(.top, 4)
            }
        }
        .growCard(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: event))
    }

    @ViewBuilder
    private func destination(for event: GardenEvent) -> some View {
        if let entry = event.journalEntry {
            JournalEntryDetailView(entry: entry)
        } else if let plant = event.plant {
            PlantDetailView(plant: plant)
        } else if let room = event.room {
            RoomDetailView(room: room)
        } else {
            Text("No linked record")
        }
    }

    private func accessibilityLabel(for event: GardenEvent) -> String {
        var parts = [
            event.kind.title,
            event.title,
            "\(Format.shortDate(event.date)) \(Format.time(event.date))"
        ]
        if let roomName = event.roomName {
            parts.append("Room \(roomName)")
        }
        if let plantName = event.plantName {
            parts.append("Plant \(plantName)")
        }
        return parts.joined(separator: ", ")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing matches these filters")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Every record is still here. Clear a filter to see the rest of the garden.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton("Show everything", systemImage: "arrow.counterclockwise") {
                selectedPlant = nil
                selectedRoom = nil
                selectedKinds = Set(GardenEventKind.allCases)
            }
        }
        .growCard()
    }

    private var footnote: some View {
        Text("This timeline reads existing records only. It adds no inference, score or suggested action.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func toggle(_ kind: GardenEventKind) {
        if selectedKinds.contains(kind) {
            selectedKinds.remove(kind)
        } else {
            selectedKinds.insert(kind)
        }
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return Format.shortDate(date)
    }
}

private struct DaySection: Identifiable {
    let id: Date
    let events: [GardenEvent]
}
