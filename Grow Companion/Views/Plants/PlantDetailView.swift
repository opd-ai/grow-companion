//
//  PlantDetailView.swift
//  Grow Companion
//
//  One plant's whole record: current stage, one-tap transitions, a backfill
//  editor for missed transitions, harvest weights and disposition, and the
//  timestamped stage history.
//

import SwiftUI
import SwiftData

struct PlantDetailView: View {
    @Bindable var plant: Plant
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Strain.name) private var strains: [Strain]
    @Query(sort: \Plant.plantedAt, order: .reverse) private var allPlants: [Plant]
    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]

    @State private var showingMotherPicker = false
    @State private var showingBackfill = false
    @State private var editingEvent: StageEvent?
    @State private var showingDeleteConfirm = false
    @State private var removalError = ""
    @State private var showingRemovalError = false
    @State private var showingHarvestSheet = false
    @State private var wetText = ""
    @State private var dryText = ""
    @State private var showingWeightsSaved = false
    @State private var showingStrainEditor = false
    @State private var ratingSelection: Int?
    @State private var tastingNotesText = ""
    @State private var showingRatingSaved = false
    @State private var showingPhotos = false
    @State private var limitWarningMessage = ""
    @State private var showingLimitWarning = false
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    private var harvestSectionVisible: Bool {
        [.harvest, .cure, .storage].contains(plant.stage)
    }

    private var photos: [PlantPhoto] {
        PhotoTimelineService.photos(from: plant.journalEntries)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                stageCard
                if !photos.isEmpty { photoTimelineCard }
                if hasLineageContent { lineageCard }
                if plant.stage == .flower { floweringCard }
                PlantTrainingSection(plant: plant)
                ScoutingCheckSection(plant: plant, room: nil)
                TreatmentSection(plant: plant)
                if harvestSectionVisible || plant.activeDryingSession != nil {
                    dryCureSection
                }
                if harvestSectionVisible { harvestCard }
                if harvestSectionVisible { ratingCard }
                if harvestSectionVisible { comparisonCard }
                if hasYield { yieldSection }
                notesCard
                historySection
                dangerZone
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(plant.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Log stage") { showingBackfill = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .sheet(isPresented: $showingBackfill) {
            StageLogSheet(plant: plant, event: nil)
        }
        .sheet(isPresented: $showingHarvestSheet) {
            HarvestPlantSheet(plant: plant)
        }
        .sheet(isPresented: $showingPhotos) {
            PhotoTimelineView(title: plant.displayName, photos: photos)
        }
        .sheet(item: $editingEvent) { event in
            StageLogSheet(plant: plant, event: event)
        }
        .sheet(isPresented: $showingStrainEditor) {
            StrainEditorView(onSaved: { strain in
                assignStrain(strain)
            })
        }
        .sheet(isPresented: $showingMotherPicker) {
            MotherPlantPickerSheet(plant: plant, candidates: motherCandidates) { mother in
                plant.mother = mother
                try? context.save()
            }
        }
        .confirmationDialog(
            "Remove this plant?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Archive and keep history") {
                archivePlant()
            }
            Button("Delete plant and its history", role: .destructive) {
                deletePlant()
            }
            Button("Keep plant", role: .cancel) {}
        } message: {
            Text("Archiving keeps every record and moves the plant out of your active garden. Deleting removes the plant and its stage, training, treatment, scouting and drying records; journal entries stay without a plant link.")
        }
        .alert("The plant was not changed", isPresented: $showingRemovalError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(removalError)
        }
        .alert("Over the plant limit", isPresented: $showingLimitWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(limitWarningMessage)
        }
        .onAppear {
            loadWeights()
            loadRating()
        }
    }

    // MARK: Header

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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.displayName)
                        .font(Theme.serif(28))
                        .foregroundStyle(Theme.ink)
                    Menu {
                        Button {
                            assignStrain(nil)
                        } label: {
                            Label("No strain", systemImage: "minus.circle")
                        }
                        if !strains.isEmpty {
                            Divider()
                            ForEach(strains) { strain in
                                Button {
                                    assignStrain(strain)
                                } label: {
                                    Text(strain.name)
                                }
                            }
                        }
                        Divider()
                        Button {
                            showingStrainEditor = true
                        } label: {
                            Label("New strain", systemImage: "plus")
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(plant.displayStrain)
                                .font(Theme.sans(14))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(Theme.secondaryInk)
                    }
                }
                Spacer()
                StageBadge(stage: plant.stage)
            }

            HStack(spacing: 8) {
                InfoChip(symbol: plant.origin.systemImage, text: plant.origin.title)
                if let room = plant.room {
                    InfoChip(symbol: room.type.systemImage, text: room.name)
                }
                if plant.isMother {
                    InfoChip(symbol: "star", text: "Mother")
                }
            }

            Divider().overlay(Theme.hairline)

            HStack(spacing: 16) {
                metric("In this stage", Format.dayCount(plant.daysInStage))
                if plant.stage == .flower {
                    metric(
                        "Typical",
                        StrainInsights.shortLengthText(days: Double(StrainInsights.expectation(for: plant).days))
                    )
                } else if let expected = plant.stage.expectedDays {
                    metric("Typical", Format.dayCount(expected))
                }
                metric("Planted", Format.shortDate(plant.plantedAt))
            }

            if plant.isStageOverdue && plant.stage != .flower {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    Text("This plant has been in \(plant.stage.title) longer than usual. If it has already moved on, log the real date so your timing stays accurate.")
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

    // MARK: Stage

    private var stageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Now", subtitle: plant.stage.title)

            Text(plant.stage.guidance)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let next = plant.stage.next {
                PrimaryButton("Move to \(next.title)", systemImage: next.systemImage) {
                    advance(to: next)
                }
                Text("The transition is timestamped automatically.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
            } else {
                Text("This plant has finished its lifecycle. Its record stays for your yield history.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            }

            SecondaryButton("Backfill a missed stage", systemImage: "clock.arrow.circlepath") {
                showingBackfill = true
            }
        }
        .growCard()
    }

    // MARK: Lineage

    private var hasLineageContent: Bool {
        plant.mother != nil || !cloneList.isEmpty || plant.origin != .seed
    }

    /// Direct clones from the inverse relationship, with a pass over all plants
    /// so the list is right even before the inverse has settled.
    private var cloneList: [Plant] {
        var result = plant.clones
        var seen = Set(result.map(\.persistentModelID))

        for candidate in allPlants
        where candidate.mother?.persistentModelID == plant.persistentModelID {
            guard !seen.contains(candidate.persistentModelID) else { continue }
            seen.insert(candidate.persistentModelID)
            result.append(candidate)
        }

        return result.sorted { $0.plantedAt > $1.plantedAt }
    }

    private var lineageSubtitle: String {
        var parts: [String] = []

        if plant.generation > 0 {
            parts.append("Generation \(plant.generation)")
        }
        if !cloneList.isEmpty {
            let count = cloneList.count
            parts.append("\(count) clone\(count == 1 ? "" : "s") taken")
        }
        if parts.isEmpty {
            return plant.origin == .seed ? "Started from seed" : "No mother recorded"
        }
        return parts.joined(separator: " · ")
    }

    private var motherCandidates: [Plant] {
        var blocked: Set<PersistentIdentifier> = [plant.persistentModelID]
        for clone in plant.descendants() {
            blocked.insert(clone.persistentModelID)
        }
        return allPlants.filter { !blocked.contains($0.persistentModelID) }
    }

    private var lineageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Lineage", subtitle: lineageSubtitle)

            if let mother = plant.mother {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.sageSoft)
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mother")
                            .font(.system(size: 10, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.tertiaryInk)

                        NavigationLink {
                            PlantDetailView(plant: mother)
                        } label: {
                            HStack(spacing: 4) {
                                Text(mother.displayName)
                                    .font(Theme.sans(15, weight: .semibold))
                                    .foregroundStyle(Theme.primary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Theme.tertiaryInk)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 6)

                    Button("Change") { showingMotherPicker = true }
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
                .padding(.vertical, 2)
            } else if plant.origin != .seed {
                HStack(alignment: .top, spacing: 10) {
                    Text("No mother recorded for this cutting.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Button("Choose") { showingMotherPicker = true }
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }

            if !cloneList.isEmpty {
                Divider().overlay(Theme.hairline)

                HStack {
                    Text("Clones taken")
                        .font(Theme.sans(10, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(Theme.secondaryInk)
                    Spacer()
                    Text("\(cloneList.count)")
                        .font(Theme.sans(11, weight: .semibold))
                        .foregroundStyle(Theme.secondaryInk)
                }

                VStack(spacing: 0) {
                    ForEach(cloneList) { clone in
                        NavigationLink {
                            PlantDetailView(plant: clone)
                        } label: {
                            cloneRow(clone)
                        }
                        .buttonStyle(.plain)

                        if clone.id != cloneList.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
            }
        }
        .growCard()
    }

    private func cloneRow(_ clone: Plant) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceSunken)
                    .frame(width: 32, height: 32)
                Image(systemName: clone.stage.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(clone.displayName)
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                HStack(spacing: 8) {
                    if let dry = clone.dryWeightGrams {
                        Text(Format.weight(dry, unit: unit))
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    if let rating = clone.rating {
                        StarRatingView(rating: rating, size: 9)
                    }
                    if clone.dryWeightGrams == nil && clone.rating == nil {
                        Text("No harvest recorded")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.tertiaryInk)
                    }
                }
            }

            Spacer(minLength: 6)

            StageBadge(stage: clone.stage)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: Flowering

    private var floweringCard: some View {
        let expectation = StrainInsights.expectation(for: plant)
        let week = StrainInsights.currentFlowerWeek(for: plant)
        let segments = max(expectation.weeks, week)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Flowering clock", subtitle: plant.strain?.displayName ?? "No strain assigned")

            HStack(alignment: .top, spacing: 16) {
                metric("Week", "\(week) of \(expectation.weeks)")
                metric("Day", "\(plant.daysInStage)")
                metric("Expected", StrainInsights.shortLengthText(days: Double(expectation.days)))
            }

            HStack(spacing: 4) {
                ForEach(1...max(1, segments), id: \.self) { index in
                    Capsule()
                        .fill(index <= week ? Theme.primary : Theme.surfaceSunken)
                        .frame(height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Flower week \(week) of \(expectation.weeks)")

            Text(expectation.sourceText)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if plant.daysInStage > expectation.days {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    Text(overrunText(expectation))
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(expectation.usesHistory ? Theme.amberSoft : Theme.surfaceSunken)
                )
            }
        }
        .growCard()
    }

    private func overrunText(_ expectation: FloweringExpectation) -> String {
        let daysPast = plant.daysInStage - expectation.days
        if expectation.usesHistory {
            let cycles = expectation.sampleCount == 1
                ? "your one finished cycle"
                : "your \(expectation.sampleCount) finished cycles"
            return "\(Format.dayCount(daysPast)) past the \(Format.dayCount(expectation.days)) your own records show across \(cycles). Judge it by trichomes and pistils now, not by the countdown."
        }
        return "\(Format.dayCount(daysPast)) past the \(Format.dayCount(expectation.days)) expectation. Check trichomes and pistils, then log the harvest so your own timing replaces this figure."
    }

    // MARK: Harvest

    private var harvestCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Harvest record", subtitle: "This app never records a sale or a transfer")

            HStack(spacing: 12) {
                weightField(title: "Wet weight", text: $wetText)
                Text("→")
                    .font(Theme.sans(16, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryInk)
                HStack(spacing: 6) {
                    TextField("0", text: $dryText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .font(Theme.sans(18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.trailing)
                    Text("g")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
            }

            HStack(spacing: 14) {
                Text("Dry weight")
                    .font(Theme.sans(11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryInk)
                Spacer()
                if let ratio = dryToWetRatio {
                    Text("Dry-to-wet \(String(format: "%.0f%%", ratio * 100))")
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }

            Button {
                saveWeights()
            } label: {
                Text(showingWeightsSaved ? "Weights saved" : "Save weights")
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.sageSoft)
                    )
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.hairline)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("What happened to it")
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(plant.harvestDisposition?.explanation ?? "Not recorded yet")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                }
                Spacer()
                Menu {
                    ForEach(HarvestDisposition.allCases) { option in
                        Button {
                            plant.harvestDisposition = option
                            try? context.save()
                        } label: {
                            Label(option.title, systemImage: option.systemImage)
                        }
                    }
                    if plant.harvestDisposition != nil {
                        Button("Clear", role: .destructive) {
                            plant.harvestDisposition = nil
                            try? context.save()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(plant.harvestDisposition?.title ?? "Choose")
                            .font(Theme.sans(13, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.sageSoft))
                }
            }
        }
        .growCard()
    }

    // MARK: Rating

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Rate this result", subtitle: "A fair judgement lands after the cure")

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        ratingSelection = ratingSelection == value ? nil : value
                        showingRatingSaved = false
                    } label: {
                        Image(systemName: (ratingSelection ?? 0) >= value ? "star.fill" : "star")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle((ratingSelection ?? 0) >= value ? Theme.primary : Theme.tertiaryInk.opacity(0.6))
                            .frame(minWidth: 34, minHeight: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                }
                Spacer(minLength: 0)
                Text(ratingSelection.map { "\($0) of 5" } ?? "Not rated")
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(ratingSelection == nil ? Theme.tertiaryInk : Theme.primary)
            }

            TextEditor(text: $tastingNotesText)
                .scrollContentBackground(.hidden)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 90)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
                .overlay(alignment: .topLeading) {
                    if tastingNotesText.isEmpty {
                        Text("Taste, smell, effect, how it burned")
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.tertiaryInk)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: tastingNotesText) { _, _ in
                    showingRatingSaved = false
                }

            Button {
                saveRating()
            } label: {
                Text(showingRatingSaved ? "Rating saved" : "Save rating")
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.sageSoft)
                    )
            }
            .buttonStyle(.plain)

            if let strain = plant.strain {
                Text("Ratings and tasting notes collect on \(strain.displayName) in the strain library.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard()
    }

    // MARK: Comparison

    private var comparisonCard: some View {
        NavigationLink {
            CycleComparisonView(plant: plant)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.sageSoft)
                        .frame(width: 34, height: 34)
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Compare with another cycle")
                        .font(Theme.sans(15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("Yield, timing and your rating side by side")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryInk)
            }
            .growCard(padding: 16)
        }
        .buttonStyle(.plain)
    }

    private func weightField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryInk)
            HStack(spacing: 6) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(Theme.sans(18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("g")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surfaceSunken)
            )
        }
    }

    // MARK: Dry and cure

    @ViewBuilder
    private var dryCureSection: some View {
        if let session = plant.activeDryingSession {
            NavigationLink {
                DryingSessionView(session: session)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionHeader(
                            session.phase == .curing ? "Curing in progress" : "Drying in progress",
                            subtitle: session.phase == .curing
                                ? HarvestLog.curingDayText(session)
                                : HarvestLog.dryingDayText(session)
                        )
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryInk)
                    }
                    Text("Open the session for daily checks, the target band and \(session.phase == .curing ? "burping" : "drying") guidance.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .growCard()
            }
            .buttonStyle(.plain)
        } else if plant.stage == .harvest {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Dry & cure")
                Text("Weigh the plant, predict the dry weight from your own harvests, and start the drying log.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton("Start drying", systemImage: "wind") {
                    showingHarvestSheet = true
                }
            }
            .growCard()
        }
    }

    // MARK: Yield

    private var hasYield: Bool {
        plant.wetWeightGrams != nil || plant.dryWeightGrams != nil
    }

    private var yieldSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Yield", subtitle: "This plant's harvest record")

            HStack(alignment: .top, spacing: 16) {
                if let wet = plant.wetWeightGrams {
                    metric("Wet", Format.weight(wet, unit: unit))
                }
                if let dry = plant.dryWeightGrams {
                    metric("Dry", Format.weight(dry, unit: unit))
                }
                if let ratio = dryToWetRatio {
                    metric("Dry-to-wet", String(format: "%.0f%%", ratio * 100))
                }
                if let gramsPerWatt {
                    metric("Per watt", String(format: "%.2f g/W", gramsPerWatt))
                }
            }

            if let watts = plant.room?.lightWatts, watts > 0 {
                Text("Grams per watt uses the \(watts) W light recorded for \(plant.room?.name ?? "the room").")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else if plant.dryWeightGrams != nil {
                Text("Record a light wattage on the room to see grams per watt.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard()
    }

    private var gramsPerWatt: Double? {
        HarvestLog.gramsPerWatt(dryGrams: plant.dryWeightGrams, watts: plant.room?.lightWatts ?? 0)
    }

    // MARK: Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Notes")
            TextEditor(text: $plant.notes)
                .scrollContentBackground(.hidden)
                .font(Theme.sans(15))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 110)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
                .overlay(alignment: .topLeading) {
                    if plant.notes.isEmpty {
                        Text("Anything worth remembering about this plant")
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.tertiaryInk)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
        .growCard()
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Stage history", subtitle: "The record every timing metric is built on")

            if plant.sortedStageEvents.isEmpty {
                Text("No stage transitions recorded yet.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard(padding: 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(plant.sortedStageEvents) { event in
                        Button {
                            editingEvent = event
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.sageSoft)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: event.stage.systemImage)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.primary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(event.stage.title)
                                            .font(Theme.sans(14, weight: .semibold))
                                            .foregroundStyle(Theme.ink)
                                        if event.isBackfilled {
                                            Pill(
                                                text: "Backfilled",
                                                tint: Theme.secondaryInk,
                                                fill: Theme.surfaceSunken
                                            )
                                        }
                                    }
                                    Text(Format.shortDate(event.date))
                                        .font(Theme.sans(12))
                                        .foregroundStyle(Theme.secondaryInk)
                                    if !event.note.isEmpty {
                                        Text(event.note)
                                            .font(Theme.sans(12))
                                            .foregroundStyle(Theme.tertiaryInk)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.tertiaryInk)
                            }
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if event.id != plant.sortedStageEvents.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }
        }
    }

    // MARK: Danger zone

    private var dangerZone: some View {
        Button {
            showingDeleteConfirm = true
        } label: {
            Text("Delete this plant")
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private var dryToWetRatio: Double? {
        guard let wet = plant.wetWeightGrams, wet > 0, let dry = plant.dryWeightGrams else { return nil }
        return dry / wet
    }

    private func loadWeights() {
        wetText = plant.wetWeightGrams.map { String(format: "%.1f", $0) } ?? ""
        dryText = plant.dryWeightGrams.map { String(format: "%.1f", $0) } ?? ""
    }

    private func loadRating() {
        ratingSelection = plant.rating
        tastingNotesText = plant.tastingNotes
    }

    private func saveRating() {
        plant.ratingRaw = ratingSelection
        plant.tastingNotes = tastingNotesText.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.ratedAt = (ratingSelection == nil && plant.tastingNotes.isEmpty) ? nil : Date()
        try? context.save()
        showingRatingSaved = true
    }

    private func assignStrain(_ strain: Strain?) {
        plant.strain = strain
        plant.strainName = strain?.name ?? ""
        try? context.save()
    }

    private func parsed(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private func saveWeights() {
        plant.wetWeightGrams = parsed(wetText)
        plant.dryWeightGrams = parsed(dryText)
        try? context.save()
        showingWeightsSaved = true
    }

    private func advance(to stage: PlantStage) {
        if let rule = profiles.first?.rule {
            let preview = QuickLogService.countPreview(
                plant: plant,
                to: stage,
                plants: allPlants,
                rule: rule,
                warningThreshold: warningThreshold
            )
            if preview.isOverLimit {
                let limitText = preview.plantLimit.map(String.init) ?? "—"
                let counting = rule.countingNote.isEmpty ? "" : " \(rule.countingNote)"
                limitWarningMessage = "Moving \(plant.displayName) to \(stage.title) would count \(preview.countedAfter) plants against a limit of \(limitText).\(counting)\n\nNo change has been saved. Verify the current rule where you live."
                showingLimitWarning = true
                return
            }
        }

        let event = StageEvent(stage: stage, date: Date())
        context.insert(event)
        event.plant = plant
        plant.stage = stage
        if stage == .harvest {
            plant.harvestedAt = Date()
        }
        try? context.save()
    }

    private func deletePlant() {
        do {
            try PlantRemovalService.delete(plant, in: context)
            dismiss()
        } catch {
            removalError = error.localizedDescription
            showingRemovalError = true
        }
    }

    /// Keeps every record and moves the plant out of the active garden.
    private func archivePlant() {
        do {
            try PlantRemovalService.archive(plant, in: context)
            dismiss()
        } catch {
            removalError = error.localizedDescription
            showingRemovalError = true
        }
    }
}

struct InfoChip: View {
    var symbol: String
    var text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(Theme.sans(12, weight: .medium))
        }
        .foregroundStyle(Theme.secondaryInk)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.surfaceSunken))
    }
}

// MARK: - Stage log sheet

struct StageLogSheet: View {
    let plant: Plant
    let event: StageEvent?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var stage: PlantStage = .veg
    @State private var date = Date()
    @State private var note = ""

    private var isEditing: Bool { event != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stage")
                                .font(Theme.sans(11, weight: .semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.secondaryInk)
                            Picker("Stage", selection: $stage) {
                                ForEach(PlantStage.allCases) { option in
                                    Text(option.title).tag(option)
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
                            Text("Adding a past transition keeps your history honest without changing the plant's current stage.")
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.tertiaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(Theme.sans(11, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.secondaryInk)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Theme.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.surfaceSunken)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)")
                            .font(Theme.sans(11, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.secondaryInk)
                        TextField("Anything to remember", text: $note, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.surfaceSunken)
                            )
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle(isEditing ? "Edit stage log" : "Log a past stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .onAppear {
            if let event {
                stage = event.stage
                date = event.date
                note = event.note
            } else {
                stage = plant.stage
                date = plant.stageStartedAt
            }
        }
    }

    private func save() {
        if let event {
            event.stage = stage
            event.date = date
            event.note = note
        } else {
            let newEvent = StageEvent(stage: stage, date: date, note: note, isBackfilled: true)
            context.insert(newEvent)
            newEvent.plant = plant
        }
        try? context.save()
        dismiss()
    }
}
