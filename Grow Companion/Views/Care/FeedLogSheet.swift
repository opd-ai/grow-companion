//
//  FeedLogSheet.swift
//  Grow Companion
//
//  Volume, pH and EC going in and coming out, compared with the room's
//  reservoir target. Drift is flagged as you type.
//

import SwiftUI
import SwiftData
import UIKit

struct FeedLogSheet: View {
    let room: Room
    var reminder: CareReminder?
    var initialKind: FeedKind

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    @State private var kind: FeedKind
    @State private var date = Date()
    @State private var volumeText = ""
    @State private var phInText = ""
    @State private var ecInText = ""
    @State private var phRunoffText = ""
    @State private var ecRunoffText = ""
    @State private var note = ""

    init(room: Room, reminder: CareReminder? = nil, initialKind: FeedKind = .water) {
        self.room = room
        self.reminder = reminder
        self.initialKind = initialKind
        _kind = State(initialValue: reminder?.kind == .feed ? .feed : initialKind)
    }

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var volumeLiters: Double? {
        guard let value = CareInput.number(volumeText) else { return nil }
        return unit == .metric ? value : value * 3.78541
    }

    private var phIn: Double? { CareInput.number(phInText) }
    private var ecIn: Double? { CareInput.number(ecInText) }
    private var phRunoff: Double? { CareInput.number(phRunoffText) }
    private var ecRunoff: Double? { CareInput.number(ecRunoffText) }

    private var hasAnything: Bool {
        volumeLiters != nil || phIn != nil || ecIn != nil || phRunoff != nil || ecRunoff != nil
    }

    /// The feed schedule week in force for this room today, if there is one.
    private var scheduledWeek: (schedule: FeedSchedule, week: FeedWeek, number: Int)? {
        guard let schedule = room.feedSchedule,
              let number = FeedScheduleEngine.currentWeek(
                startDate: room.feedScheduleStartDate,
                weekCount: schedule.weekCount
              ),
              let week = schedule.week(number)
        else { return nil }
        return (schedule, week, number)
    }

    private var targetPH: Double? {
        scheduledWeek?.week.targetPH ?? room.feedTargetPH
    }

    private var targetEC: Double? {
        scheduledWeek?.week.targetEC ?? room.feedTargetEC
    }

    private var driftPreview: [FeedDriftItem] {
        CareLog.drift(
            targetPH: targetPH,
            targetEC: targetEC,
            phIn: phIn,
            ecIn: ecIn,
            phRunoff: phRunoff,
            ecRunoff: ecRunoff
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(kind == .feed ? "Log a feed" : "Log a watering")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("\(room.name) · readings are compared with the feed target in force.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                    }

                    Picker("Kind", selection: $kind) {
                        ForEach(FeedKind.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("When")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        DatePicker("", selection: $date)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .growCard(padding: 14)

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Volume (\(unit == .metric ? "L" : "gal"))")
                        CareInput.field(
                            placeholder: unit == .metric ? "2.5" : "0.66",
                            text: $volumeText
                        )
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            CareInput.label("pH in")
                            CareInput.field(placeholder: "6.2", text: $phInText)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            CareInput.label("EC in")
                            CareInput.field(placeholder: "1.6", text: $ecInText)
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            CareInput.label("Runoff pH")
                            CareInput.field(placeholder: "6.4", text: $phRunoffText)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            CareInput.label("Runoff EC")
                            CareInput.field(placeholder: "1.8", text: $ecRunoffText)
                        }
                    }

                    targetCard

                    if !driftPreview.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.amber)
                                Text("Drift from target")
                                    .font(Theme.sans(13, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                            }
                            ForEach(driftPreview) { item in
                                Text("\(item.label): \(item.message)")
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.secondaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .growCard(fill: Theme.amberSoft, padding: 14)
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

                    PrimaryButton(
                        kind == .feed ? "Save feed" : "Save watering",
                        systemImage: "checkmark",
                        isEnabled: hasAnything
                    ) {
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
        .onAppear { prefillFromSchedule() }
        .onChange(of: kind) { _, newValue in
            if newValue == .feed {
                prefillFromSchedule()
            }
        }
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            CareInput.label(scheduledWeek == nil ? "Reservoir target" : "Feed schedule target")

            if let scheduled = scheduledWeek {
                Text("\(scheduled.schedule.displayName) · Week \(scheduled.number)")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if targetPH == nil && targetEC == nil {
                Text("No target set for this room yet. Set one from the Feeding section to see drift.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 8) {
                    if let ph = targetPH {
                        Pill(text: "pH \(String(format: "%.1f", ph))", systemImage: "paintpalette", tint: Theme.primary, fill: Theme.sageSoft)
                    }
                    if let ec = targetEC {
                        Pill(text: "EC \(String(format: "%.2f", ec))", systemImage: "bolt.horizontal", tint: Theme.primary, fill: Theme.sageSoft)
                    }
                }
            }
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14)
    }

    private func prefillFromSchedule() {
        guard kind == .feed, phInText.isEmpty, ecInText.isEmpty else { return }
        guard let scheduled = scheduledWeek else { return }

        if let ph = scheduled.week.targetPH {
            phInText = String(format: "%.1f", ph)
        }
        if let ec = scheduled.week.targetEC {
            ecInText = String(format: "%.2f", ec)
        }
    }

    private func save() {
        let event = FeedEvent(
            date: date,
            kind: kind,
            volumeLiters: volumeLiters,
            phIn: phIn,
            ecIn: ecIn,
            phRunoff: phRunoff,
            ecRunoff: ecRunoff,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(event)
        event.room = room

        if let reminder {
            CareLog.complete(reminder)
        }

        try? context.save()
        dismiss()
    }
}
