//
//  LightScheduleEditor.swift
//  Grow Companion
//
//  Presets or custom on/off times. A change made while plants in the room are
//  flowering needs an explicit confirmation, and every change is logged.
//

import SwiftUI
import SwiftData

struct LightScheduleEditor: View {
    @Bindable var room: Room

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var preset: LightPreset = .eighteenSix
    @State private var onTime = Date()
    @State private var offTime = Date()
    @State private var note = ""
    @State private var showingFlowerWarning = false

    private var newOnMinutes: Int { LightSchedule.minutes(from: onTime) }
    private var newOffMinutes: Int { LightSchedule.minutes(from: offTime) }

    private var hasChanged: Bool {
        newOnMinutes != room.lightsOnMinutes || newOffMinutes != room.lightsOffMinutes
    }

    private var timesAreValid: Bool { newOnMinutes != newOffMinutes }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Light schedule")
                            .font(Theme.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text("Set the photoperiod for \(room.name). Grow Companion does not control your hardware — it shows the schedule and the next change.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if room.hasFloweringPlants {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.amber)
                            Text("\(room.floweringPlantCount) plant\(room.floweringPlantCount == 1 ? "" : "s") in this room are flowering. Changing the light schedule during flower can stress plants and stall bud development — you'll be asked to confirm.")
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .growCard(fill: Theme.amberSoft, padding: 14)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Preset")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                            ForEach(LightPreset.allCases) { option in
                                Button {
                                    preset = option
                                    syncOffTime()
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(option.title)
                                            .font(Theme.sans(14, weight: .semibold))
                                        Text(option.subtitle)
                                            .font(Theme.sans(10))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                    .foregroundStyle(preset == option ? Theme.primary : Theme.secondaryInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(preset == option ? Theme.sageSoft : Theme.surfaceSunken)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.primary)
                                Text("Lights on")
                                    .font(Theme.sans(14))
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                            Spacer()
                            DatePicker("", selection: $onTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(Theme.primary)
                        }

                        Divider().overlay(Theme.hairline)

                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "moon")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.primary)
                                Text("Lights off")
                                    .font(Theme.sans(14))
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                            Spacer()
                            DatePicker("", selection: $offTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(Theme.primary)
                                .disabled(preset != .custom)
                                .opacity(preset == .custom ? 1 : 0.45)
                        }

                        Divider().overlay(Theme.hairline)

                        HStack {
                            Text("Schedule")
                                .font(Theme.sans(13))
                                .foregroundStyle(Theme.secondaryInk)
                            Spacer()
                            Text(LightSchedule.summary(on: newOnMinutes, off: newOffMinutes))
                                .font(Theme.sans(13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }

                        if !timesAreValid {
                            Text("Lights on and off cannot be the same time.")
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.amber)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .growCard(padding: 16)

                    VStack(alignment: .leading, spacing: 6) {
                        label("Note (optional)")
                        TextField("Why is the schedule changing?", text: $note, axis: .vertical)
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

                    PrimaryButton("Save schedule", systemImage: "checkmark", isEnabled: timesAreValid) {
                        attemptSave()
                    }

                    if !hasChanged {
                        Text("The schedule is unchanged. Saving will just close this screen.")
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.tertiaryInk)
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
            .confirmationDialog(
                "Change the schedule during flowering?",
                isPresented: $showingFlowerWarning,
                titleVisibility: .visible
            ) {
                Button("Change the schedule anyway", role: .destructive) {
                    applyChange()
                }
                Button("Keep the current schedule", role: .cancel) {}
            } message: {
                Text("\(room.floweringPlantCount) plant\(room.floweringPlantCount == 1 ? "" : "s") in \(room.name) are flowering. A photoperiod change can cause stress or stalled flowering. The change and your note are recorded in the room's override log.")
            }
        }
        .onAppear(perform: load)
        .onChange(of: preset) { _, _ in
            syncOffTime()
        }
        .onChange(of: onTime) { _, _ in
            if preset != .custom { syncOffTime() }
        }
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(Theme.sans(11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryInk)
    }

    private func load() {
        onTime = LightSchedule.date(forMinutes: room.lightsOnMinutes)
        offTime = LightSchedule.date(forMinutes: room.lightsOffMinutes)
        preset = LightPreset.matching(hours: room.lightHoursPerDay)
    }

    private func syncOffTime() {
        guard let hours = preset.hoursOfLight else { return }
        offTime = Calendar.current.date(byAdding: .minute, value: hours * 60, to: onTime) ?? onTime
    }

    private func attemptSave() {
        guard timesAreValid else { return }
        guard hasChanged else {
            dismiss()
            return
        }
        if room.hasFloweringPlants {
            showingFlowerWarning = true
        } else {
            applyChange()
        }
    }

    private func applyChange() {
        let event = LightScheduleEvent(
            date: Date(),
            previousOnMinutes: room.lightsOnMinutes,
            previousOffMinutes: room.lightsOffMinutes,
            newOnMinutes: newOnMinutes,
            newOffMinutes: newOffMinutes,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            hadFloweringPlants: room.hasFloweringPlants
        )
        context.insert(event)
        event.room = room

        room.lightsOnMinutes = newOnMinutes
        room.lightsOffMinutes = newOffMinutes

        try? context.save()
        dismiss()
    }
}
