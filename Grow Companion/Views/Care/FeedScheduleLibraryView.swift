//
//  FeedScheduleLibraryView.swift
//  Grow Companion
//
//  The feed schedule library: every saved week-by-week mix, what is applied to
//  a room, and the current week's mix for the room you came from.
//

import SwiftUI
import SwiftData

struct FeedScheduleLibraryView: View {
    var room: Room? = nil

    @Query(sort: \FeedSchedule.createdAt, order: .reverse) private var schedules: [FeedSchedule]

    @State private var showingEditor = false

    private var sortedSchedules: [FeedSchedule] {
        schedules.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if sortedSchedules.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 14) {
                        ForEach(sortedSchedules) { schedule in
                            NavigationLink {
                                FeedScheduleDetailView(schedule: schedule)
                            } label: {
                                FeedScheduleCard(schedule: schedule, room: room)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let room, room.feedSchedule != nil {
                    thisWeekSection(room)
                }

                SecondaryButton("Add a schedule", systemImage: "plus") {
                    showingEditor = true
                }

                Text("Doses are per litre of water. Applying a schedule only sets targets; every feed still gets logged.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Feed schedules")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) {
            FeedScheduleEditorView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Feed schedules")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("One mix per week, ready to repeat")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "flask")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text("No feed schedules yet")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Save the mix you repeat, week by week, then apply it to a room. The room shows the current week's products and targets.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    @ViewBuilder
    private func thisWeekSection(_ room: Room) -> some View {
        if let schedule = room.feedSchedule {
            let weekNumber = FeedScheduleEngine.currentWeek(
                startDate: room.feedScheduleStartDate,
                weekCount: schedule.weekCount
            )

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("This week in \(room.name)", subtitle: schedule.displayName)

                if let weekNumber, let week = schedule.week(weekNumber) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Week \(weekNumber) of \(schedule.weekCount)")
                                .font(Theme.sans(13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            FeedWeekTargetPills(week: week)
                        }
                        FeedWeekMixRows(week: week)
                    }
                    .growCard(padding: 16)
                } else {
                    Text(FeedScheduleEngine.statusText(schedule: schedule, room: room) ?? "No mix for this week yet.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .growCard(padding: 16)
                }
            }
        }
    }
}

// MARK: - Card

struct FeedScheduleCard: View {
    let schedule: FeedSchedule
    let room: Room?

    private var appliedContext: (room: Room, week: Int)? {
        let candidates: [Room] = ([room].compactMap { $0 }) + schedule.sortedAppliedRooms

        for candidate in candidates {
            guard candidate.feedSchedule?.persistentModelID == schedule.persistentModelID else { continue }
            if let week = FeedScheduleEngine.currentWeek(
                startDate: candidate.feedScheduleStartDate,
                weekCount: schedule.weekCount
            ) {
                return (candidate, week)
            }
        }
        return nil
    }

    private var referenceRoom: Room? {
        if let room, room.feedSchedule?.persistentModelID == schedule.persistentModelID {
            return room
        }
        return schedule.sortedAppliedRooms.first
    }

    private var filledWeeks: Int {
        if let appliedContext { return appliedContext.week }
        guard let referenceRoom,
              FeedScheduleEngine.isFinished(
                startDate: referenceRoom.feedScheduleStartDate,
                weekCount: schedule.weekCount
              )
        else { return 0 }
        return schedule.weekCount
    }

    private var appliedLabel: String {
        let rooms = schedule.sortedAppliedRooms
        guard let first = rooms.first else { return "Applied" }
        if rooms.count == 1 { return "Applied to \(first.name)" }
        return "Applied to \(first.name) +\(rooms.count - 1)"
    }

    private var statusLine: (text: String, tint: Color)? {
        guard let referenceRoom else { return nil }

        if FeedScheduleEngine.isPending(startDate: referenceRoom.feedScheduleStartDate) {
            let date = referenceRoom.feedScheduleStartDate.map(Format.shortDate) ?? "soon"
            return ("Starts \(date)", Theme.secondaryInk)
        }

        if let appliedContext, let week = schedule.week(appliedContext.week) {
            var parts = ["Week \(appliedContext.week)"]
            if let ec = week.targetEC {
                parts.append("\(String(format: "%.2f", ec)) EC")
            }
            if let ph = week.targetPH {
                parts.append("\(String(format: "%.1f", ph)) pH")
            }
            return (parts.joined(separator: " · "), Theme.primary)
        }

        if FeedScheduleEngine.isFinished(
            startDate: referenceRoom.feedScheduleStartDate,
            weekCount: schedule.weekCount
        ) {
            return ("All \(schedule.weekCount) weeks complete", Theme.secondaryInk)
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(schedule.displayName) · \(schedule.weekCount) weeks")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)

            HStack(spacing: 6) {
                Pill(
                    text: "\(schedule.weekCount) weeks",
                    systemImage: "calendar",
                    tint: Theme.secondaryInk,
                    fill: Theme.surfaceSunken
                )

                if schedule.isApplied {
                    Pill(
                        text: appliedLabel,
                        systemImage: "door.left.hand.open",
                        tint: Theme.primary,
                        fill: Theme.sageSoft
                    )
                } else {
                    Pill(
                        text: "Not in use",
                        systemImage: "minus.circle",
                        tint: Theme.secondaryInk,
                        fill: Theme.surfaceSunken
                    )
                }
            }

            HStack(spacing: 3) {
                ForEach(1...max(1, schedule.weekCount), id: \.self) { index in
                    Capsule()
                        .fill(index <= filledWeeks ? Theme.primary : Theme.surfaceSunken)
                        .frame(height: 6)
                }
            }
            .accessibilityLabel("\(filledWeeks) of \(schedule.weekCount) weeks")

            if let statusLine {
                Text(statusLine.text)
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(statusLine.tint)
            }
        }
        .growCard(padding: 16)
    }
}
