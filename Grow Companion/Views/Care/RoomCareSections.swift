//
//  RoomCareSections.swift
//  Grow Companion
//
//  The care panels on a room dashboard: environment, feeding, calibration and
//  reminders.
//

import SwiftUI
import SwiftData

// MARK: - Environment

struct RoomEnvironmentSection: View {
    @Bindable var room: Room

    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @State private var metric: EnvironmentMetric = .temperature
    @State private var showingLog = false

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var subtitle: String {
        guard let latest = room.latestEnvironmentReading else { return String(localized: "No readings yet") }
        return String(localized: "Last reading \(Format.shortDate(latest.date)) at \(Format.time(latest.date))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Environment", subtitle: subtitle)

            if let latest = room.latestEnvironmentReading {
                HStack(spacing: 10) {
                    valueCell(
                        "Temp",
                        value: latest.temperatureC.map { Format.temperature($0, unit: unit) } ?? "—",
                        out: isOut(latest.temperatureC, range: room.targetTemperatureRange)
                    )
                    valueCell(
                        "RH",
                        value: latest.humidityPercent.map { String(format: "%.0f%%", $0) } ?? "—",
                        out: isOut(latest.humidityPercent, range: room.targetHumidityRange)
                    )
                    valueCell(
                        "Light",
                        value: latest.lightPPFD.map { String(format: "%.0f", $0) } ?? "—",
                        out: false
                    )
                }
                HStack(spacing: 5) {
                    Image(systemName: latest.source == .sensor ? "checkmark.shield.fill" : "pencil")
                    Text(latest.source == .sensor ? "Sensor-sourced" : "Manual entry")
                }
                .font(Theme.sans(11, weight: .semibold))
                .foregroundStyle(latest.source == .sensor ? Theme.primary : Theme.secondaryInk)
            }

            if let temperature = room.targetTemperatureRange, let humidity = room.targetHumidityRange {
                Text("Target for \(room.dominantStage?.title.lowercased() ?? "veg"): \(Format.temperatureRange(temperature, unit: unit)) · \(String(format: "%.0f–%.0f%%", humidity.lowerBound, humidity.upperBound)) humidity")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("Alert after")
                    .font(Theme.sans(13, weight: .medium))
                    .foregroundStyle(Theme.secondaryInk)
                Spacer()
                Picker("Alert duration", selection: $room.sustainedAlertMinutes) {
                    ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .labelsHidden()
                .tint(Theme.primary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))
            .onChange(of: room.sustainedAlertMinutes) { _, _ in try? context.save() }

            Picker("Metric", selection: $metric) {
                ForEach(EnvironmentMetric.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            EnvironmentChartView(
                readings: room.sortedEnvironmentReadings,
                metric: metric,
                targetRange: metric.target(in: room),
                unit: unit
            )

            PrimaryButton("Log a reading", systemImage: "plus") {
                showingLog = true
            }
        }
        .growCard()
        .sheet(isPresented: $showingLog) {
            EnvironmentLogSheet(room: room)
        }
    }

    private func valueCell(_ title: String, value: String, out: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(Theme.secondaryInk)
            Text(value)
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(out ? Theme.danger : Theme.ink)
            if out {
                Text("Out of range")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.amber)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(out ? Theme.amberSoft : Theme.surfaceSunken)
        )
        .accessibilityElement(children: .combine)
    }

    private func isOut(_ value: Double?, range: ClosedRange<Double>?) -> Bool {
        guard let value, let range else { return false }
        return !range.contains(value)
    }
}

// MARK: - Feeding

struct RoomFeedingSection: View {
    let room: Room

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @State private var showingLog = false
    @State private var logKind: FeedKind = .water
    @State private var showingTargets = false

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var events: [FeedEvent] {
        Array(room.sortedFeedEvents.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Feeding", subtitle: targetSubtitle)

            HStack(spacing: 8) {
                if let ph = room.feedTargetPH {
                    Pill(text: "pH \(String(format: "%.1f", ph))", systemImage: "paintpalette")
                }
                if let ec = room.feedTargetEC {
                    Pill(text: "EC \(String(format: "%.2f", ec))", systemImage: "bolt.horizontal")
                }
                Spacer(minLength: 0)
                Button(room.feedTargetPH == nil && room.feedTargetEC == nil ? "Set target" : "Edit target") {
                    showingTargets = true
                }
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.primary)
            }

            if events.isEmpty {
                Text("No waterings or feeds logged for this room yet.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(events) { event in
                        FeedEventRow(event: event, room: room, unit: unit)
                        if event.id != events.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }

            HStack(spacing: 10) {
                SecondaryButton("Log watering", systemImage: "drop") {
                    logKind = .water
                    showingLog = true
                }
                SecondaryButton("Log feed", systemImage: "flask") {
                    logKind = .feed
                    showingLog = true
                }
            }
        }
        .growCard()
        .sheet(isPresented: $showingLog) {
            FeedLogSheet(room: room, initialKind: logKind)
        }
        .sheet(isPresented: $showingTargets) {
            FeedTargetSheet(room: room)
        }
    }

    private var targetSubtitle: String {
        if room.feedTargetPH == nil && room.feedTargetEC == nil {
            return String(localized: "No reservoir target set")
        }
        return String(localized: "Compared with your reservoir target")
    }
}

struct FeedEventRow: View {
    let event: FeedEvent
    let room: Room
    let unit: UnitSystem

    private var drift: [FeedDriftItem] { CareLog.drift(for: event, room: room) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sageSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: event.kind.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.kind.title)
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 6)
                    Text("\(Format.shortDate(event.date)) · \(Format.time(event.date))")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                }

                HStack(spacing: 10) {
                    if let volume = event.volumeLiters {
                        Text(Format.volume(volume, unit: unit))
                    }
                    if let ph = event.phIn {
                        Text("pH in \(String(format: "%.1f", ph))")
                    }
                    if let ec = event.ecIn {
                        Text("EC in \(String(format: "%.2f", ec))")
                    }
                    if let runoffPH = event.phRunoff {
                        Text("runoff pH \(String(format: "%.1f", runoffPH))")
                    }
                    if let runoffEC = event.ecRunoff {
                        Text("runoff EC \(String(format: "%.2f", runoffEC))")
                    }
                }
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

                if let first = drift.first {
                    Text("\(first.label): \(first.message)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !event.note.isEmpty {
                    Text(event.note)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Calibration

struct RoomCalibrationSection: View {
    let room: Room

    @State private var showingLog = false

    private var events: [CalibrationEvent] {
        Array(room.sortedCalibrationEvents.prefix(3))
    }

    private var nextDue: Date? { room.nextCalibrationDue }

    private var isOverdue: Bool {
        guard let nextDue else { return false }
        return nextDue <= Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Calibration", subtitle: subtitle)

            if events.isEmpty {
                Text("No meter calibrations logged yet. A drifting pH meter will send every reading out of range.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: event.meter.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.meter.title)
                                    .font(Theme.sans(14, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text("Calibrated \(Format.shortDate(event.date))" + (event.reading.map { " · reading \(String(format: "%.2f", $0))" } ?? ""))
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.secondaryInk)
                                if let due = event.nextDueDate {
                                    Text(due <= Date() ? "Was due \(Format.shortDate(due))" : "Next due \(Format.shortDate(due))")
                                        .font(Theme.sans(11, weight: .semibold))
                                        .foregroundStyle(due <= Date() ? Theme.amber : Theme.primary)
                                }
                                if !event.note.isEmpty {
                                    Text(event.note)
                                        .font(Theme.sans(12))
                                        .foregroundStyle(Theme.tertiaryInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 9)
                        .accessibilityElement(children: .combine)

                        if event.id != events.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }

            PrimaryButton("Log calibration", systemImage: "gauge.with.dots.needle.50percent") {
                showingLog = true
            }
        }
        .growCard()
        .sheet(isPresented: $showingLog) {
            CalibrationLogSheet(room: room)
        }
    }

    private var subtitle: String {
        guard let nextDue else { return String(localized: "No calibration scheduled") }
        return isOverdue
            ? "Overdue since \(Format.shortDate(nextDue))"
            : "Next due \(Format.shortDate(nextDue))"
    }
}

// MARK: - Reminders

struct RoomRemindersSection: View {
    let room: Room

    @Environment(\.modelContext) private var context
    @State private var showingNew = false
    @State private var editingReminder: CareReminder?

    private var reminders: [CareReminder] {
        room.careReminders.sorted { $0.nextDueDate < $1.nextDueDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                "Care reminders",
                subtitle: reminders.isEmpty ? "None scheduled" : "\(reminders.count) scheduled"
            )

            if reminders.isEmpty {
                Text("Schedule watering, feeding, reading and calibration reminders. They arrive as local notifications.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(reminders) { reminder in
                        HStack(alignment: .center, spacing: 10) {
                            Button {
                                editingReminder = reminder
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: reminder.kind.systemImage)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.primary)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reminder.displayTitle)
                                            .font(Theme.sans(14, weight: .semibold))
                                            .foregroundStyle(Theme.ink)
                                        Text("\(reminder.repeatLabel) · \(reminder.isDue ? "due now" : Format.shortDate(reminder.nextDueDate) + " at " + Format.time(reminder.nextDueDate))")
                                            .font(Theme.sans(11))
                                            .foregroundStyle(reminder.isDue ? Theme.amber : Theme.secondaryInk)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Toggle("", isOn: toggleBinding(for: reminder))
                                .labelsHidden()
                                .tint(Theme.primary)
                        }
                        .padding(.vertical, 7)

                        if reminder.id != reminders.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }

            SecondaryButton("Add a reminder", systemImage: "plus") {
                showingNew = true
            }
        }
        .growCard()
        .sheet(isPresented: $showingNew) {
            CareReminderEditor(room: room)
        }
        .sheet(item: $editingReminder) { reminder in
            CareReminderEditor(room: room, reminder: reminder)
        }
    }

    private func toggleBinding(for reminder: CareReminder) -> Binding<Bool> {
        Binding(
            get: { reminder.isEnabled },
            set: { newValue in
                reminder.isEnabled = newValue
                try? context.save()
                if newValue {
                    CareNotifications.schedule(reminder)
                } else {
                    CareNotifications.cancel(reminder)
                }
            }
        )
    }
}

// MARK: - Reminder log dispatcher

struct ReminderLogSheet: View {
    let reminder: CareReminder

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let room = reminder.room {
            switch reminder.kind {
            case .reading:
                EnvironmentLogSheet(room: room, reminder: reminder)
            case .water, .feed:
                FeedLogSheet(
                    room: room,
                    reminder: reminder,
                    initialKind: reminder.kind == .feed ? .feed : .water
                )
            case .calibration:
                CalibrationLogSheet(room: room, reminder: reminder)
            }
        } else {
            VStack(spacing: 12) {
                Text("This reminder is not linked to a room.")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryInk)
                SecondaryButton("Close") { dismiss() }
            }
            .padding(24)
        }
    }
}
