//
//  CareReminderEditor.swift
//  Grow Companion
//
//  A watering, feeding, reading or calibration prompt, with its local
//  notification.
//

import SwiftUI
import SwiftData

struct CareReminderEditor: View {
    let room: Room
    var reminder: CareReminder?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var kind: CareReminderKind = .water
    @State private var time = Date()
    @State private var repeatDays = 1
    @State private var isEnabled = true
    @State private var showingDelete = false

    private let repeatOptions = [1, 2, 3, 7, 14, 30]

    private var isEditing: Bool { reminder != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "Edit reminder" : "New reminder")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("Reminders belong to \(room.name) and arrive as local notifications.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Title")
                        CareInput.field(
                            placeholder: kind.title,
                            text: $title,
                            keyboard: .default
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Reminder")
                        Menu {
                            ForEach(CareReminderKind.allCases) { option in
                                Button {
                                    kind = option
                                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        title = ""
                                    }
                                } label: {
                                    Label(option.title, systemImage: option.systemImage)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: kind.systemImage)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(kind.title)
                                    .font(Theme.sans(14, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(Theme.primary)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.sageSoft)
                            )
                        }
                    }

                    HStack {
                        Text("Time")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .growCard(padding: 14)

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Repeat")
                        Picker("Repeat", selection: $repeatDays) {
                            ForEach(repeatOptions, id: \.self) { days in
                                Text(days == 1 ? "Every day" : "Every \(days) days").tag(days)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.surfaceSunken)
                        )
                    }

                    Toggle(isOn: $isEnabled) {
                        Text("Reminder is on")
                            .font(Theme.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.primary)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )

                    PrimaryButton("Save reminder", systemImage: "checkmark") {
                        save()
                    }

                    if isEditing {
                        Button {
                            showingDelete = true
                        } label: {
                            Text("Delete reminder")
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
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
            .confirmationDialog("Delete this reminder?", isPresented: $showingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
                Button("Keep it", role: .cancel) {}
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let reminder else { return }
        title = reminder.title
        kind = reminder.kind
        repeatDays = reminder.repeatDays
        isEnabled = reminder.isEnabled
        time = LightSchedule.date(forMinutes: reminder.timeOfDayMinutes)
    }

    private func save() {
        let minutes = LightSchedule.minutes(from: time)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let target: CareReminder
        if let reminder {
            target = reminder
        } else {
            let created = CareReminder(room: room)
            context.insert(created)
            created.room = room
            target = created
        }

        target.title = trimmedTitle
        target.kind = kind
        target.timeOfDayMinutes = minutes
        target.repeatDays = repeatDays
        target.isEnabled = isEnabled
        target.nextDueDate = CareLog.nextDue(
            after: Date(),
            intervalDays: repeatDays,
            timeOfDayMinutes: minutes
        )

        try? context.save()

        if isEnabled {
            Task {
                _ = await CareNotifications.requestAuthorization()
                CareNotifications.schedule(target)
            }
        } else {
            CareNotifications.cancel(target)
        }

        dismiss()
    }

    private func delete() {
        guard let reminder else { return }
        CareNotifications.cancel(reminder)
        context.delete(reminder)
        try? context.save()
        dismiss()
    }
}
