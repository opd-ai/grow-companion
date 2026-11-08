//
//  FeedScheduleDetailView.swift
//  Grow Companion
//
//  One feed schedule: its weeks and targets, the room it is applied to, and
//  the route to duplicate or delete it.
//

import SwiftUI
import SwiftData

struct FeedScheduleDetailView: View {
    @Bindable var schedule: FeedSchedule

    @Query(sort: \Room.createdAt) private var rooms: [Room]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRoom: Room?
    @State private var startDate = Date()
    @State private var showingEditor = false
    @State private var showingDelete = false
    @State private var duplicateName: String?
    @State private var appliedMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                applyCard
                weeksSection
                duplicateButton
                dangerZone
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(schedule.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .onAppear(perform: selectDefaultRoom)
        .sheet(isPresented: $showingEditor) {
            FeedScheduleEditorView(schedule: schedule)
        }
        .alert(
            "Schedule duplicated",
            isPresented: Binding(
                get: { duplicateName != nil },
                set: { if !$0 { duplicateName = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(duplicateName ?? "The copy") is in the library, ready to tweak for the next run.")
        }
        .confirmationDialog(
            "Delete this feed schedule?",
            isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete schedule", role: .destructive) {
                deleteSchedule()
            }
            Button("Keep schedule", role: .cancel) {}
        } message: {
            Text("Any room using it stops showing a feed mix. The feed you already logged stays.")
        }
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.displayName)
                    .font(Theme.serif(28))
                    .foregroundStyle(Theme.ink)
                Text(
                    "\(schedule.weekCount) week\(schedule.weekCount == 1 ? "" : "s") · "
                        + (schedule.isApplied ? "Applied to \(schedule.appliedNames)" : "Not in use")
                )
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Pill(
                    text: "\(schedule.weekCount) weeks",
                    systemImage: "calendar",
                    tint: Theme.secondaryInk,
                    fill: Theme.surfaceSunken
                )
                if schedule.isApplied {
                    Pill(text: "In use", systemImage: "checkmark", tint: Theme.primary)
                } else {
                    Pill(
                        text: "Not in use",
                        systemImage: "minus.circle",
                        tint: Theme.secondaryInk,
                        fill: Theme.surfaceSunken
                    )
                }
            }
        }
        .growCard()
    }

    // MARK: Apply

    private var applyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Apply to a room", subtitle: "Sets this week's mix and targets")

            if rooms.isEmpty {
                Text("Add a room first, then apply a feed schedule to it.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(rooms) { room in
                            roomChip(room)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .accessibilityLabel("Choose a room")

                HStack {
                    Text("Week 1 starts")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryInk)
                    Spacer()
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Theme.primary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )

                PrimaryButton(
                    selectedRoom.map { "Apply to \($0.name)" } ?? "Select a room",
                    systemImage: "checkmark",
                    isEnabled: selectedRoom != nil
                ) {
                    apply()
                }

                if let appliedMessage {
                    Text(appliedMessage)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .growCard()
    }

    private func roomChip(_ room: Room) -> some View {
        let isSelected = selectedRoom?.persistentModelID == room.persistentModelID

        return Button {
            selectedRoom = room
            if room.feedSchedule?.persistentModelID == schedule.persistentModelID,
               let existing = room.feedScheduleStartDate {
                startDate = existing
            } else {
                startDate = Date()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: room.type.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(room.name)
                    .font(Theme.sans(13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Theme.primary : Theme.secondaryInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isSelected ? Theme.sageSoft : Theme.surfaceSunken)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Weeks

    private var weeksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Weeks")

            if schedule.sortedWeeks.isEmpty {
                Text("No weeks recorded yet. Edit this schedule to add them.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard(padding: 16)
            } else {
                ForEach(schedule.sortedWeeks) { week in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Week \(week.weekNumber)")
                                .font(Theme.sans(15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            FeedWeekTargetPills(week: week)
                        }
                        FeedWeekMixRows(week: week)
                    }
                    .growCard(padding: 16)
                }
            }
        }
    }

    // MARK: Actions

    private var duplicateButton: some View {
        SecondaryButton("Duplicate schedule", systemImage: "doc.on.doc") {
            let copy = FeedScheduleEngine.duplicate(schedule, context: context)
            duplicateName = copy.displayName
        }
    }

    private var dangerZone: some View {
        Button {
            showingDelete = true
        } label: {
            Text("Delete this schedule")
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private func selectDefaultRoom() {
        guard selectedRoom == nil else { return }

        if let applied = schedule.sortedAppliedRooms.first {
            selectedRoom = applied
            if let existing = applied.feedScheduleStartDate {
                startDate = existing
            }
        } else if let first = rooms.first {
            selectedRoom = first
        }
    }

    private func apply() {
        guard let room = selectedRoom else { return }
        room.feedSchedule = schedule
        room.feedScheduleStartDate = startDate
        try? context.save()
        appliedMessage = "Applied to \(room.name)."
    }

    private func deleteSchedule() {
        context.delete(schedule)
        try? context.save()
        dismiss()
    }
}
