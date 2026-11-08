//
//  CalibrationLogSheet.swift
//  Grow Companion
//
//  Records a pH meter or EC probe calibration and keeps the calibration
//  reminder in step with the next due date.
//

import SwiftUI
import SwiftData

struct CalibrationLogSheet: View {
    let room: Room
    var reminder: CareReminder?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var meter: CalibrationMeter = .phMeter
    @State private var date = Date()
    @State private var readingText = ""
    @State private var note = ""
    @State private var nextDue = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Log calibration")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("Meters drift. Record each calibration and when the next one is due for \(room.name).")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Picker("Meter", selection: $meter) {
                        ForEach(CalibrationMeter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Calibrated on")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        DatePicker("", selection: $date)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .growCard(padding: 14)

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label(meter == .phMeter ? "Buffer reading (pH 7.0 expected)" : "Reference reading (EC)")
                        CareInput.field(placeholder: meter == .phMeter ? "7.0" : "1.41", text: $readingText)
                    }

                    HStack {
                        Text("Next calibration due")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryInk)
                        Spacer()
                        DatePicker("", selection: $nextDue, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .growCard(padding: 14)

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Note (optional)")
                        TextField("Buffer lot, storage solution, anything to remember", text: $note, axis: .vertical)
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

                    PrimaryButton("Save calibration", systemImage: "checkmark") {
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
        .onAppear {
            if let reminder, reminder.kind == .calibration {
                nextDue = max(reminder.nextDueDate, Date().addingTimeInterval(60))
            }
        }
    }

    private func save() {
        let event = CalibrationEvent(
            date: date,
            meter: meter,
            reading: CareInput.number(readingText),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            nextDueDate: nextDue
        )
        context.insert(event)
        event.room = room

        upsertReminder(meter: meter, nextDue: nextDue)

        if let reminder {
            CareLog.complete(reminder)
        }

        try? context.save()
        dismiss()
    }

    private func upsertReminder(meter: CalibrationMeter, nextDue: Date) {
        let existing = room.careReminders.first { $0.kind == .calibration }
        let calibrationReminder: CareReminder

        if let existing {
            calibrationReminder = existing
        } else {
            let created = CareReminder(
                title: "Calibrate \(meter.title)",
                kind: .calibration,
                timeOfDayMinutes: LightSchedule.minutes(from: nextDue),
                repeatDays: 30,
                nextDueDate: nextDue
            )
            context.insert(created)
            created.room = room
            calibrationReminder = created
        }

        calibrationReminder.title = "Calibrate \(meter.title)"
        calibrationReminder.isEnabled = true
        calibrationReminder.nextDueDate = max(nextDue, Date().addingTimeInterval(60))
        CareNotifications.schedule(calibrationReminder)
    }
}
