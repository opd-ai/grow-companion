//
//  QuickLogSheet.swift
//  Grow Companion
//
//  One sheet for the four routine actions. Everything is local state until the
//  grower taps save; the service performs the single write.
//

import SwiftUI
import SwiftData
import os

struct QuickLogSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8

    @State private var action: QuickLogAction = .water
    @State private var feedKind: FeedKind = .water
    @State private var selectedRoom: Room?
    @State private var selectedPlant: Plant?
    @State private var newStage: PlantStage?

    @State private var volumeText = ""
    @State private var phInText = ""
    @State private var ecInText = ""
    @State private var temperatureText = ""
    @State private var humidityText = ""
    @State private var lightText = ""
    @State private var noteText = ""

    @State private var feedPrefillDate: Date?
    @State private var readingPrefillDate: Date?
    @State private var initialized = false

    @State private var errorMessage = ""
    @State private var showingError = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GrowCompanion",
        category: "QuickLog"
    )

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }
    private var rule: JurisdictionRule? { profiles.first?.rule }

    private var activePlants: [Plant] { plants.filter(\.isActive) }

    private var plantsForSelection: [Plant] {
        guard let selectedRoom else { return activePlants }
        return activePlants.filter {
            $0.room?.persistentModelID == selectedRoom.persistentModelID
        }
    }

    private var volumeLiters: Double? {
        guard let value = CareInput.number(volumeText) else { return nil }
        return unit == .metric ? value : value * 3.78541
    }

    private var phIn: Double? { CareInput.number(phInText) }
    private var ecIn: Double? { CareInput.number(ecInText) }
    private var lightValue: Double? { CareInput.number(lightText) }

    private var temperatureValue: Double? {
        guard let raw = CareInput.number(temperatureText) else { return nil }
        return unit == .metric ? raw : (raw - 32) * 5 / 9
    }

    private var humidityValue: Double? { CareInput.number(humidityText) }

    private var temperatureValid: Bool {
        guard let temperatureValue else { return true }
        return (-20...60).contains(temperatureValue)
    }

    private var humidityValid: Bool {
        guard let humidityValue else { return true }
        return (0...100).contains(humidityValue)
    }

    private var trimmedNote: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var stagePreview: PlantCountPreview? {
        guard let selectedPlant, let newStage, let rule else { return nil }
        return QuickLogService.countPreview(
            plant: selectedPlant,
            to: newStage,
            plants: plants,
            rule: rule,
            warningThreshold: warningThreshold
        )
    }

    private var isBlockedByLimit: Bool {
        stagePreview?.isOverLimit == true
    }

    private var canSave: Bool {
        switch action {
        case .water:
            return selectedRoom != nil
        case .reading:
            return selectedRoom != nil
                && (temperatureValue != nil || humidityValue != nil || lightValue != nil)
                && temperatureValid
                && humidityValid
        case .note:
            return !trimmedNote.isEmpty
        case .stage:
            return selectedPlant != nil
                && newStage != nil
                && newStage != selectedPlant?.stage
                && !isBlockedByLimit
        }
    }

    private var saveTitle: String {
        switch action {
        case .water:
            return feedKind == .water ? "Save watering" : "Save feed"
        case .reading:
            return "Save reading"
        case .note:
            return "Save note"
        case .stage:
            return "Move to \(newStage?.title ?? "next stage")"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    actionGrid
                    contextCard
                    form
                    if action == .stage {
                        stagePreviewCard
                        if isBlockedByLimit { blockedCard }
                    }
                    if !isBlockedByLimit {
                        PrimaryButton(saveTitle, systemImage: "checkmark", isEnabled: canSave) {
                            save()
                        }
                    }
                    Text("Nothing is saved until you confirm. Cancel closes this sheet and writes nothing.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .padding(.bottom, 20)
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
            .alert("Could not save", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear(perform: initializeIfNeeded)
        .onChange(of: selectedRoom) { _, _ in
            selectedPlant = defaultPlant(in: selectedRoom)
            syncStageSelection()
            applyFeedPrefill(force: true)
            applyReadingPrefill(force: true)
        }
        .onChange(of: selectedPlant) { _, _ in
            syncStageSelection()
        }
    }

    // MARK: Header and actions

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick log")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Four routine actions, one sheet. The last room and plant are remembered, and the last values are filled in for you to edit.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(QuickLogAction.allCases) { option in
                Button {
                    select(action: option)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: option.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                            Spacer(minLength: 0)
                            if action == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundStyle(action == option ? Theme.primary : Theme.secondaryInk)

                        Text(option.title)
                            .font(Theme.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text(option.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.secondaryInk)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(action == option ? Theme.sageSoft : Theme.surfaceSunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                action == option ? Theme.primary.opacity(0.35) : Theme.hairline,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.title): \(option.subtitle)")
                .accessibilityAddTraits(action == option ? .isSelected : [])
            }
        }
    }

    // MARK: Context

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Where")

            roomPicker

            if action == .water {
                Picker("Kind", selection: $feedKind) {
                    ForEach(FeedKind.allCases) { kind in
                        Text(optionTitle(kind)).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            if action == .note || action == .stage {
                plantPicker
            }
        }
        .growCard(padding: 16)
    }

    private func optionTitle(_ kind: FeedKind) -> String {
        kind == .water ? "Water" : "Feed"
    }

    private var roomPicker: some View {
        Menu {
            ForEach(rooms) { room in
                Button(room.name) { selectedRoom = room }
            }
        } label: {
            pickerRow(
                title: selectedRoom?.name ?? (rooms.isEmpty ? "No rooms yet" : "Choose a room"),
                symbol: selectedRoom?.type.systemImage ?? "tent",
                isSet: selectedRoom != nil
            )
        }
        .disabled(rooms.isEmpty)
        .accessibilityLabel("Room: \(selectedRoom?.name ?? "not chosen")")
    }

    private var plantPicker: some View {
        Menu {
            Button("No plant") { selectedPlant = nil }
            ForEach(plantsForSelection) { plant in
                Button(plant.displayName) { selectedPlant = plant }
            }
        } label: {
            pickerRow(
                title: selectedPlant?.displayName ?? "No plant",
                symbol: "leaf",
                isSet: selectedPlant != nil
            )
        }
        .disabled(plantsForSelection.isEmpty)
        .accessibilityLabel("Plant: \(selectedPlant?.displayName ?? "none")")
    }

    private func pickerRow(title: String, symbol: String, isSet: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(Theme.sans(14, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(isSet ? Theme.primary : Theme.secondaryInk)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSet ? Theme.sageSoft : Theme.surfaceSunken)
        )
    }

    // MARK: Forms

    @ViewBuilder
    private var form: some View {
        switch action {
        case .water:
            feedForm
        case .reading:
            readingForm
        case .note:
            noteForm
        case .stage:
            stageForm
        }
    }

    private var feedForm: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            if let date = feedPrefillDate {
                prefillCaption(date)
            }
        }
        .growCard(padding: 16)
    }

    private var readingForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                CareInput.label("Temperature (\(unit == .metric ? "°C" : "°F"))")
                CareInput.field(
                    placeholder: unit == .metric ? "24.5" : "76.1",
                    text: $temperatureText
                )
                if !temperatureValid {
                    CareInput.warning("Temperature is outside the range a grow room can plausibly be in.")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                CareInput.label("Relative humidity (%)")
                CareInput.field(placeholder: "55", text: $humidityText)
                if !humidityValid {
                    CareInput.warning("Humidity has to be between 0 and 100%.")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                CareInput.label("Light (PPFD)")
                CareInput.field(placeholder: "450", text: $lightText)
            }

            if let date = readingPrefillDate {
                prefillCaption(date)
            }
        }
        .growCard(padding: 16)
    }

    private var noteForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            CareInput.label("Note")
            TextField("What happened?", text: $noteText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
                .lineLimit(3...6)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
        }
        .growCard(padding: 16)
    }

    private var stageForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let plant = selectedPlant {
                InfoRow(label: "Current stage", value: plant.stage.title)
            }

            Menu {
                ForEach(PlantStage.allCases) { stage in
                    Button {
                        newStage = stage
                    } label: {
                        Label(stage.title, systemImage: stage.systemImage)
                    }
                }
            } label: {
                pickerRow(
                    title: newStage?.title ?? "Choose a stage",
                    symbol: newStage?.systemImage ?? "arrow.triangle.2.circlepath",
                    isSet: newStage != nil
                )
            }
            .disabled(selectedPlant == nil)
            .accessibilityLabel("New stage: \(newStage?.title ?? "not chosen")")
        }
        .growCard(padding: 16)
    }

    private func prefillCaption(_ date: Date) -> some View {
        Text("Filled from your last log on \(Format.shortDate(date)). These are starting values, not new measurements — edit anything that differs.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Stage preview

    @ViewBuilder
    private var stagePreviewCard: some View {
        if let preview = stagePreview {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Counted plants after this change")
                HStack(spacing: 10) {
                    Text("\(preview.countedAfter) of \(preview.plantLimit.map(String.init) ?? "—")")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Pill(
                        text: preview.level.title,
                        systemImage: preview.level.symbolName,
                        tint: preview.level.tint,
                        fill: preview.level.softFill
                    )
                }
                Text("Before the change: \(preview.countedBefore) counted.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryInk)
            }
            .growCard(fill: Theme.surfaceSunken, padding: 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "After this change \(preview.countedAfter) plants count against a limit of \(preview.plantLimit.map(String.init) ?? "no recorded limit"), \(preview.level.title)"
            )
        }
    }

    @ViewBuilder
    private var blockedCard: some View {
        if let preview = stagePreview, let rule {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon")
                        .font(.system(size: 15, weight: .semibold))
                    Text("This would take you over the plant limit")
                        .font(Theme.sans(15, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.danger)

                Text("After this change \(preview.countedAfter) plants would count against a limit of \(preview.plantLimit.map(String.init) ?? "—"). \(rule.countingNote)")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(rule.citation)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text("No change has been saved. Verify the current rule where you live before you proceed.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .growCard(fill: Theme.dangerSoft, padding: 16)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Actions

    private func select(action newAction: QuickLogAction) {
        guard action != newAction else { return }
        action = newAction

        switch newAction {
        case .water:
            applyFeedPrefill(force: false)
        case .reading:
            applyReadingPrefill(force: false)
        case .stage:
            syncStageSelection()
        case .note:
            break
        }
    }

    private func initializeIfNeeded() {
        guard !initialized else { return }
        initialized = true

        let preferredRoom = QuickLogPreferences.resolvedRoom(
            named: QuickLogPreferences.roomName,
            in: rooms
        )
        selectedRoom = preferredRoom ?? rooms.first
        selectedPlant = defaultPlant(in: selectedRoom)
        syncStageSelection()
        applyFeedPrefill(force: true)
        applyReadingPrefill(force: true)
    }

    private func defaultPlant(in room: Room?) -> Plant? {
        let candidates: [Plant]
        if let room {
            candidates = activePlants.filter {
                $0.room?.persistentModelID == room.persistentModelID
            }
        } else {
            candidates = activePlants
        }

        if let remembered = QuickLogPreferences.resolvedPlant(
            named: QuickLogPreferences.plantName,
            in: candidates
        ) {
            return remembered
        }
        return candidates.first
    }

    private func syncStageSelection() {
        guard let plant = selectedPlant else {
            newStage = nil
            return
        }
        if newStage == nil || newStage == plant.stage {
            newStage = plant.stage.next
        }
    }

    private func applyFeedPrefill(force: Bool) {
        guard let room = selectedRoom else {
            feedPrefillDate = nil
            return
        }
        guard force || (volumeText.isEmpty && phInText.isEmpty && ecInText.isEmpty) else { return }
        guard let prefill = QuickLogService.feedPrefill(for: room) else {
            feedPrefillDate = nil
            return
        }

        feedKind = prefill.kind
        volumeText = prefill.volumeLiters.map(volumeFieldText) ?? ""
        phInText = prefill.phIn.map { fieldText($0, digits: 1) } ?? ""
        ecInText = prefill.ecIn.map { fieldText($0, digits: 2) } ?? ""
        feedPrefillDate = prefill.date
    }

    private func applyReadingPrefill(force: Bool) {
        guard let room = selectedRoom else {
            readingPrefillDate = nil
            return
        }
        guard force
            || (temperatureText.isEmpty && humidityText.isEmpty && lightText.isEmpty) else {
            return
        }
        guard let prefill = QuickLogService.readingPrefill(for: room) else {
            readingPrefillDate = nil
            return
        }

        temperatureText = prefill.temperatureC.map(temperatureFieldText) ?? ""
        humidityText = prefill.humidityPercent.map { fieldText($0, digits: 0) } ?? ""
        lightText = prefill.lightPPFD.map { fieldText($0, digits: 0) } ?? ""
        readingPrefillDate = prefill.date
    }

    private func volumeFieldText(_ liters: Double) -> String {
        switch unit {
        case .metric:
            return fieldText(liters, digits: 2)
        case .imperial:
            return fieldText(liters / 3.78541, digits: 2)
        }
    }

    private func temperatureFieldText(_ celsius: Double) -> String {
        switch unit {
        case .metric:
            return fieldText(celsius, digits: 1)
        case .imperial:
            return fieldText(celsius * 9 / 5 + 32, digits: 1)
        }
    }

    private func fieldText(_ value: Double, digits: Int) -> String {
        String(
            format: "%.\(digits)f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }

    private func save() {
        guard canSave else { return }

        do {
            switch action {
            case .water:
                guard let room = selectedRoom else { throw QuickLogError.missingRoom }
                _ = try QuickLogService.logFeed(
                    room: room,
                    kind: feedKind,
                    volumeLiters: volumeLiters,
                    phIn: phIn,
                    ecIn: ecIn,
                    in: context
                )

            case .reading:
                guard let room = selectedRoom else { throw QuickLogError.missingRoom }
                _ = try QuickLogService.logReading(
                    room: room,
                    temperatureC: temperatureValue,
                    humidityPercent: humidityValue,
                    lightPPFD: lightValue,
                    in: context
                )

            case .note:
                _ = try QuickLogService.logNote(
                    text: noteText,
                    plant: selectedPlant,
                    room: selectedRoom,
                    in: context
                )

            case .stage:
                guard let plant = selectedPlant else { throw QuickLogError.missingPlant }
                guard let stage = newStage else { throw QuickLogError.missingPlant }
                _ = try QuickLogService.changeStage(plant: plant, to: stage, in: context)
            }

            dismiss()
        } catch {
            logger.error(
                "Quick log save failed: \(error.localizedDescription, privacy: .public)"
            )
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
