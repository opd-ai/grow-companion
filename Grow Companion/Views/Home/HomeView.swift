//
//  HomeView.swift
//  Grow Companion
//
//  Today at a glance: the compliance ring with the counting logic beside it,
//  what needs attention, the plants, and the latest journal entries.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    let profile: GrowProfile

    @Environment(\.modelContext) private var context
    @Environment(ComplianceHistoryMonitor.self) private var historyMonitor
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journal: [JournalEntry]
    @Query(sort: \EnvironmentReading.date) private var allReadings: [EnvironmentReading]
    @Query(sort: \RuleEvaluationEvent.evaluatedAt, order: .reverse)
    private var ruleEvaluations: [RuleEvaluationEvent]

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8

    @State private var showingAddPlant = false
    @State private var showingBreakdown = false
    @State private var showingQuickLog = false
    @State private var showingRoomEditor = false
    @State private var showingHistory = false
    @State private var showingRuleReview = false
    @State private var selectedRoom: Room?
    @State private var selectedFamily: Plant?
    @State private var loggingReminder: CareReminder?

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }
    private var rule: JurisdictionRule? { profile.rule }

    private var pendingRuleChanges: [RuleEvaluationEvent] {
        ruleEvaluations.filter { !$0.isAcknowledged }
    }

    private var historyCaption: String {
        guard let saved = historyMonitor.lastSavedAt else {
            return "History starts with this update"
        }
        return "Saved \(Format.shortDate(saved)) at \(Format.time(saved))"
    }

    private var report: ComplianceReport? {
        guard let rule else { return nil }
        return ComplianceEngine.report(
            plants: visiblePlants,
            rooms: filteredRooms,
            rule: rule,
            warningThreshold: warningThreshold
        )
    }

    private var visiblePlants: [Plant] {
        guard let selectedRoom else { return plants }
        return plants.filter { $0.room?.persistentModelID == selectedRoom.persistentModelID }
    }

    private var filteredRooms: [Room] {
        guard let selectedRoom else { return rooms }
        return [selectedRoom]
    }

    private var activePlants: [Plant] { visiblePlants.filter { $0.isActive } }

    /// The plant list honours the family filter; the compliance card and tasks
    /// stay scoped to the selected room.
    private var plantsForList: [Plant] {
        guard let selectedFamily else { return activePlants }
        return activePlants.filter {
            $0.familyRoot.persistentModelID == selectedFamily.persistentModelID
        }
    }

    private var familyRoots: [Plant] {
        var roots: [PersistentIdentifier: Plant] = [:]

        for plant in plants where plant.mother != nil || !plant.clones.isEmpty {
            let root = plant.familyRoot
            roots[root.persistentModelID] = root
        }

        return roots.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var filteredJournal: [JournalEntry] {
        guard let selectedRoom else { return journal }
        return journal.filter { entry in
            entry.room?.persistentModelID == selectedRoom.persistentModelID
                || entry.plant?.room?.persistentModelID == selectedRoom.persistentModelID
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                quickActions
                if !rooms.isEmpty { roomFilter }
                if !familyRoots.isEmpty { familyFilter }
                if !pendingRuleChanges.isEmpty {
                    RuleUpdateBanner(events: pendingRuleChanges) {
                        showingRuleReview = true
                    }
                }
                complianceCard
                todaySection
                plantsSection
                roomsSection
                if !filteredJournal.isEmpty { latestJournalSection }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAddPlant) {
            AddPlantView(preselectedRoom: selectedRoom)
        }
        .sheet(isPresented: $showingQuickLog) {
            QuickLogSheet()
        }
        .sheet(isPresented: $showingRoomEditor) {
            RoomEditorView()
        }
        .sheet(isPresented: $showingBreakdown) {
            if let report, let rule {
                ComplianceBreakdownSheet(
                    report: report,
                    rooms: ComplianceEngine.breakdown(plants: visiblePlants, rooms: filteredRooms, rule: rule)
                )
            }
        }
        .sheet(isPresented: $showingHistory) {
            ComplianceHistoryView()
        }
        .sheet(isPresented: $showingRuleReview) {
            RuleChangeReviewView(events: pendingRuleChanges)
        }
        .onChange(of: rooms) { _, newRooms in
            guard let current = selectedRoom else { return }
            if !newRooms.contains(where: { $0 === current }) {
                selectedRoom = nil
            }
        }
        .onChange(of: plants) { _, newPlants in
            guard let family = selectedFamily else { return }
            let roots = newPlants
                .filter { $0.mother != nil || !$0.clones.isEmpty }
                .map { $0.familyRoot }
            if !roots.contains(where: { $0.persistentModelID == family.persistentModelID }) {
                selectedFamily = nil
            }
        }
        .onAppear {
            CareLog.compact(readings: allReadings, context: context)
        }
        .sheet(item: $loggingReminder) { reminder in
            ReminderLogSheet(reminder: reminder)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(Theme.sans(11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(Theme.secondaryInk)

                Text(headline)
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .semibold))
                    Text(profile.jurisdictionLabel.isEmpty ? "Jurisdiction not set" : profile.jurisdictionLabel)
                        .font(Theme.sans(12, weight: .medium))
                    if profile.jurisdictionConfirmedAt != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.primary)
                    }
                }
                .foregroundStyle(Theme.secondaryInk)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                NavigationLink {
                    CycleArchiveView()
                } label: {
                    Image(systemName: "archivebox")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cycle archive")

                NavigationLink {
                    GrowCalculatorsView()
                } label: {
                    Image(systemName: "function")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Grow calculators")

                NavigationLink {
                    WeeklyRecapView()
                } label: {
                    Image(systemName: "newspaper")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Weekly recap")

                NavigationLink {
                    RoomComparisonView()
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Compare rooms")

                NavigationLink {
                    HarvestCalendarView()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Harvest calendar")
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                showingQuickLog = true
            } label: {
                quickActionCard(
                    title: "Quick Log",
                    subtitle: "Water, reading, note or stage",
                    symbol: "plus.circle.fill",
                    isProminent: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quick Log: water, reading, note or stage change")

            NavigationLink {
                GardenTimelineView()
            } label: {
                quickActionCard(
                    title: "Garden timeline",
                    subtitle: "Every record, dated",
                    symbol: "list.bullet.rectangle.portrait",
                    isProminent: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Garden timeline")

            NavigationLink {
                GrowCalendarView()
            } label: {
                quickActionCard(
                    title: "Grow calendar",
                    subtitle: "Reminders and windows",
                    symbol: "calendar.day.timeline.leading",
                    isProminent: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Grow calendar")
        }
    }

    private func quickActionCard(
        title: String,
        subtitle: String,
        symbol: String,
        isProminent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isProminent ? Theme.primaryBright : Theme.primary)
                .padding(.bottom, 2)

            Text(title)
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(isProminent ? Theme.onHero : Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(isProminent ? Theme.onHeroSecondary : Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isProminent ? Theme.hero : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night check"
        }
    }

    private var headline: String {
        if activePlants.isEmpty { return "Let's get your first plant in." }
        if activePlants.count == 1 { return "One plant in the garden." }
        return "\(activePlants.count) plants in the garden."
    }

    // MARK: Compliance

    @ViewBuilder
    private var complianceCard: some View {
        if let report, let rule {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compliance")
                            .font(Theme.sans(10, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(1.4)
                            .foregroundStyle(Theme.onHeroSecondary)
                        Text(report.statusTitle)
                            .font(Theme.sans(19, weight: .semibold))
                            .foregroundStyle(Theme.onHero)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: report.overallLevel.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(report.overallLevel.heroTint)
                }

                HStack(spacing: 18) {
                    ComplianceRing(
                        counted: report.countedPlants,
                        limit: report.plantLimit,
                        level: report.plantLevel,
                        size: 128
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        MetricLine(
                            label: "Possession",
                            value: "\(Format.weight(report.possessionGrams, unit: unit)) / \(Format.weightLimit(report.possessionLimitGrams, unit: unit))",
                            tint: report.possessionLevel.heroTint
                        )
                        MetricLine(
                            label: "Canopy",
                            value: report.canopyLimitSqM == nil
                                ? Format.area(report.canopySqM, unit: unit)
                                : "\(Format.area(report.canopySqM, unit: unit)) / \(Format.areaLimit(report.canopyLimitSqM, unit: unit))",
                            tint: report.canopyLevel.heroTint
                        )
                        MetricLine(
                            label: "Rules updated",
                            value: RulePack.displayDate(rule.verifiedOn)
                        )
                    }
                }

                if !rule.countingNote.isEmpty {
                    Text(rule.countingNote)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.onHeroSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    showingBreakdown = true
                } label: {
                    HStack {
                        Text("How this is counted")
                            .font(Theme.sans(13, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.onHero)
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)

                Divider().overlay(Theme.onHero.opacity(0.12))

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: historyMonitor.lastError == nil ? "clock.arrow.circlepath" : "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(historyMonitor.lastError == nil ? Theme.primaryBright : Theme.amberBright)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compliance history")
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.onHero)
                        Text(historyMonitor.lastError ?? historyCaption)
                            .font(.system(size: 11))
                            .foregroundStyle(historyMonitor.lastError == nil ? Theme.onHeroSecondary : Theme.amberBright)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if historyMonitor.lastSavedAt != nil {
                        Button {
                            showingHistory = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("View")
                                    .font(Theme.sans(12, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(Theme.onHero)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View compliance history")
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .growCard(fill: Theme.hero, padding: 20)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("No jurisdiction set")
                    .font(Theme.sans(16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Choose your state in the Rules tab so Grow Companion can apply the right limits.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .growCard()
        }
    }

    // MARK: Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Today", subtitle: tasks.isEmpty ? "Nothing is overdue" : "\(tasks.count) thing\(tasks.count == 1 ? "" : "s") worth a look")

            if tasks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nothing due today.")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("A quick photo and a line of notes is the cheapest habit in growing. Future you will want it.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    SecondaryButton("Log a check-in", systemImage: "square.and.pencil") {
                        showingQuickLog = true
                    }
                }
                .growCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        if let plant = task.plant {
                            NavigationLink {
                                PlantDetailView(plant: plant)
                            } label: {
                                TaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                        } else if let reminder = task.reminder {
                            Button {
                                loggingReminder = reminder
                            } label: {
                                TaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                        } else {
                            TaskRow(task: task)
                        }
                        if task.id != tasks.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)
            }
        }
    }

    private var tasks: [HomeTask] {
        var items: [HomeTask] = []

        for reminder in dueReminders {
            tasksAppend(
                &items,
                HomeTask(
                    id: "reminder-\(reminder.notificationIdentifier)",
                    title: reminder.displayTitle,
                    detail: "\(reminder.kind.title) due \(Format.shortDate(reminder.nextDueDate)) · tap to log it",
                    symbol: reminder.kind.systemImage,
                    plant: nil,
                    reminder: reminder
                )
            )
        }

        for plant in activePlants {
            let expectation = StrainInsights.expectation(for: plant)
            let isOverdue = plant.stage == .flower
                ? plant.daysInStage > expectation.days + StrainInsights.graceDays
                : plant.isStageOverdue

            if isOverdue {
                tasksAppend(
                    &items,
                    HomeTask(
                        id: "overdue-\(plant.displayName)-\(plant.stage.rawValue)",
                        title: "Check on \(plant.displayName)",
                        detail: overdueDetail(for: plant, expectation: expectation),
                        symbol: "clock",
                        plant: plant
                    )
                )
            }

            if plant.stage == .harvest && plant.dryWeightGrams == nil {
                tasksAppend(
                    &items,
                    HomeTask(
                        id: "dry-weight-\(plant.displayName)",
                        title: "Record dry weight",
                        detail: "Weigh \(plant.displayName) once drying is done so the yield history stays honest.",
                        symbol: "scalemass",
                        plant: plant
                    )
                )
            }

            if [.harvest, .cure, .storage].contains(plant.stage) && plant.harvestDisposition == nil {
                tasksAppend(
                    &items,
                    HomeTask(
                        id: "disposition-\(plant.displayName)",
                        title: "Say what happened to the harvest",
                        detail: "Retained, consumed at home or destroyed. This app never records a sale or a transfer.",
                        symbol: "tray.and.arrow.down",
                        plant: plant
                    )
                )
            }
        }

        return items
    }

    private func overdueDetail(for plant: Plant, expectation: FloweringExpectation) -> String {
        if plant.stage == .flower {
            if expectation.usesHistory {
                let cycles = expectation.sampleCount == 1
                    ? "your finished cycle"
                    : "your \(expectation.sampleCount) finished cycles"
                return "\(Format.dayCount(plant.daysInStage)) in flower, past the \(Format.dayCount(expectation.days)) seen across \(cycles). Check trichomes."
            }
            return "\(Format.dayCount(plant.daysInStage)) in flower, past the \(Format.dayCount(expectation.days)) expected. Check trichomes."
        }
        return "\(Format.dayCount(plant.daysInStage)) in \(plant.stage.title). Move it on if it is ready."
    }

    private func tasksAppend(_ target: inout [HomeTask], _ task: HomeTask) {
        guard !target.contains(where: { $0.id == task.id }) else { return }
        guard target.count < 4 else { return }
        target.append(task)
    }

    private var dueReminders: [CareReminder] {
        let scopedRooms = selectedRoom.map { [$0] } ?? rooms
        return scopedRooms
            .flatMap { $0.careReminders }
            .filter { $0.isEnabled && $0.nextDueDate <= Date() }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    // MARK: Plants

    private var plantsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Your plants", subtitle: plantsForList.isEmpty ? "None yet" : "\(plantsForList.count) active")

            if plantsForList.isEmpty {
                if activePlants.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add your first plant")
                            .font(Theme.sans(15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("A seed, a clone or a cutting. Assign it a room and advance stages as it grows.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                        PrimaryButton("Add a plant", systemImage: "plus") {
                            showingAddPlant = true
                        }
                    }
                    .growCard()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No active plants in this family")
                            .font(Theme.sans(15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Clear the family filter to see the rest of this room.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                        SecondaryButton("Show all families", systemImage: "arrow.triangle.branch") {
                            selectedFamily = nil
                        }
                    }
                    .growCard()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(plantsForList) { plant in
                        NavigationLink {
                            PlantDetailView(plant: plant)
                        } label: {
                            PlantRow(plant: plant)
                        }
                        .buttonStyle(.plain)

                        if plant.id != plantsForList.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)

                SecondaryButton("Add a plant", systemImage: "plus") {
                    showingAddPlant = true
                }
            }
        }
    }

    // MARK: Family filter

    private var familyFilter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Family")
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(Theme.secondaryInk)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    familyChip("All families", isSelected: selectedFamily == nil) {
                        selectedFamily = nil
                    }

                    ForEach(familyRoots) { root in
                        familyChip(
                            "\(root.displayName)'s family",
                            isSelected: selectedFamily?.persistentModelID == root.persistentModelID
                        ) {
                            selectedFamily = root
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .accessibilityLabel("Filter by family")
    }

    private func familyChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(13, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.onHero : Theme.secondaryInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected ? Theme.primary : Theme.surfaceSunken)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Journal

    private var latestJournalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Latest from the journal")
            VStack(spacing: 0) {
                ForEach(filteredJournal.prefix(2)) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: entry.kind.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.text.isEmpty ? entry.kind.title : entry.text)
                                .font(Theme.sans(13))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                            Text("\(Format.shortDate(entry.createdAt)) · \(Format.time(entry.createdAt))")
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.tertiaryInk)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)
                }
            }
            .growCard(padding: 14)
        }
    }

    // MARK: Rooms

    private var roomFilter: some View {
        RoomFilterChips(rooms: rooms, selectedRoom: $selectedRoom)
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Rooms", subtitle: rooms.isEmpty ? "None yet" : "\(rooms.count)")

            if rooms.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add your first room")
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("A tent, a closet, a whole room, a greenhouse or an outdoor plot. Each room keeps its own canopy and light schedule.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton("Add a room", systemImage: "plus") {
                        showingRoomEditor = true
                    }
                }
                .growCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(rooms) { room in
                        NavigationLink {
                            RoomDetailView(room: room)
                        } label: {
                            RoomRow(room: room)
                        }
                        .buttonStyle(.plain)

                        if room.id != rooms.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .growCard(padding: 14)

                SecondaryButton("Add a room", systemImage: "plus") {
                    showingRoomEditor = true
                }
            }
        }
    }
}

// MARK: - Rows

struct HomeTask: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let plant: Plant?
    var reminder: CareReminder? = nil
}

struct TaskRow: View {
    let task: HomeTask

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sageSoft)
                    .frame(width: 34, height: 34)
                Image(systemName: task.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(Theme.sans(15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(task.detail)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if task.plant != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryInk)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct PlantRow: View {
    let plant: Plant
    var showsTraining: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.sageSoft)
                    .frame(width: 44, height: 44)
                Image(systemName: plant.stage.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(plant.displayName)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(secondaryText)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
                if let treatment = TreatmentLog.activeWithdrawal(for: plant), let endDate = treatment.withdrawalEndDate {
                    Label("Withdrawal ends \(Format.shortDate(endDate))", systemImage: "flag.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                        .lineLimit(1)
                }
                if showsTraining {
                    Text(trainingText)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            StageBadge(stage: plant.stage)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var trainingText: String {
        guard let date = plant.lastTrainingDate else { return "No training recorded" }
        return "Last trained \(Format.shortDate(date)) · \(TrainingLog.relativeText(date))"
    }

    private var secondaryText: String {
        if plant.stage == .flower {
            let expectation = StrainInsights.expectation(for: plant)
            let week = StrainInsights.currentFlowerWeek(for: plant)
            return "\(plant.displayStrain) · week \(week) of \(expectation.weeks)"
        }
        return "\(plant.displayStrain) · \(Format.dayCount(plant.daysInStage)) in \(plant.stage.shortTitle)"
    }
}

// MARK: - Breakdown sheet

struct ComplianceBreakdownSheet: View {
    let report: ComplianceReport
    let rooms: [RoomComplianceBreakdown]

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(report.countedPlants) of \(report.plantLimit.map(String.init) ?? "—") plants counted")
                            .font(Theme.serif(24))
                            .foregroundStyle(Theme.ink)
                        Text(report.rule.countingNote)
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .growCard()

                    SectionHeader("By room")
                    if rooms.isEmpty {
                        Text("No plant is currently counted on your plants list.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .growCard(padding: 16)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(rooms) { room in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(room.roomName)
                                            .font(Theme.sans(15, weight: .semibold))
                                            .foregroundStyle(Theme.ink)
                                        Text(room.plantNames.joined(separator: ", "))
                                            .font(Theme.sans(12))
                                            .foregroundStyle(Theme.secondaryInk)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 8)
                                    Text("\(room.countedPlants)")
                                        .font(Theme.sans(16, weight: .semibold))
                                        .foregroundStyle(Theme.primary)
                                }
                                .padding(.vertical, 10)
                                if room.id != rooms.last?.id {
                                    Divider().overlay(Theme.hairline)
                                }
                            }
                        }
                        .growCard(padding: 14)
                    }

                    SectionHeader("Everything else")
                    VStack(spacing: 10) {
                        InfoRow(label: "Stored flower", value: Format.weight(report.possessionGrams, unit: unit))
                        InfoRow(label: "Stored flower limit", value: Format.weightLimit(report.possessionLimitGrams, unit: unit))
                        InfoRow(label: "Canopy in use", value: Format.area(report.canopySqM, unit: unit))
                        InfoRow(label: "Canopy limit", value: Format.areaLimit(report.canopyLimitSqM, unit: unit))
                    }
                    .growCard()

                    ChartTableDisclosure(
                        table: ChartTables.compliance(report: report, unit: unit)
                    )
                    .growCard()

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                        Text("Every action you take here — deleting a plant, moving a plant on, changing a canopy — updates this count immediately.")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .growCard(fill: Theme.sageSoft, padding: 14)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}


struct RoomRow: View {
    let room: Room

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surfaceSunken)
                    .frame(width: 44, height: 44)
                Image(systemName: room.type.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(room.name)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(room.type.title) · \(room.plants.count) plant\(room.plants.count == 1 ? "" : "s") · \(room.lightScheduleSummary)")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
