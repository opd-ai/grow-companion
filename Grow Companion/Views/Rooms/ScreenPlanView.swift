//
//  ScreenPlanView.swift
//  Grow Companion
//
//  The room's training screen: a small preview on the dashboard, and the
//  planner itself — a grid of squares the grower fills with the branches they
//  tucked under the net. The plan is a map, never a measurement, and it stays on
//  the device with the rest of the room's records.
//

import SwiftData
import SwiftUI

// MARK: - Dashboard card

/// The room dashboard's screen card: how much of the net is filled, a small
/// preview of it, and the way into the planner.
struct ScreenPlanCard: View {
    let room: Room

    @State private var showingPlanner = false

    private var plan: ScreenPlan? { room.screenPlan }

    private var subtitle: String {
        guard let plan else { return String(localized: "Not set up yet") }
        return ScreenPlanner.summary(of: plan)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Screen (SCROG)", subtitle: subtitle)

            if let plan, plan.filledCount > 0 {
                ScreenGridPreview(plan: plan)
            } else {
                Text("A screen is a net you tuck branches under so the canopy fills evenly. Place each branch in the square it sits in and the grid keeps your own map of it.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            }

            SecondaryButton(
                plan == nil
                    ? String(localized: "Plan the screen")
                    : String(localized: "Open the screen planner"),
                systemImage: "square.grid.3x3"
            ) {
                showingPlanner = true
            }
        }
        .growCard()
        .sheet(isPresented: $showingPlanner) {
            ScreenPlanView(room: room)
        }
    }
}

/// A read-only miniature of the plan for the dashboard: one thin bar per
/// square, filled where a branch is placed.
struct ScreenGridPreview: View {
    let plan: ScreenPlan

    private var rows: [[ScreenGridCell]] {
        let cells = ScreenPlanner.cells(of: plan)
        return (0..<max(0, plan.rows)).map { row in
            cells.filter { $0.row == row }
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 3) {
                    ForEach(row) { cell in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(cell.isFilled ? Theme.primary.opacity(0.7) : Theme.surfaceSunken)
                            .frame(height: 7)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Planner

struct ScreenPlanView: View {
    let room: Room

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var plan: ScreenPlan?
    @State private var selectedPlantID: PersistentIdentifier?
    @State private var showingClearConfirmation = false
    @State private var showingResizeConfirmation = false
    @State private var pendingSize: ScreenSize?
    @State private var lostPositions = 0
    @State private var errorMessage: String?
    @State private var isLoading = true

    private var plants: [Plant] {
        room.plants.sorted { $0.plantedAt < $1.plantedAt }
    }

    private var selectedPlant: Plant? {
        guard let selectedPlantID else { return nil }
        return plants.first { $0.persistentModelID == selectedPlantID }
    }

    private var stats: ScreenPlanStats? {
        plan.map { ScreenPlanner.stats(of: $0) }
    }

    private var counts: [ScreenPlantCount] {
        plan.map { ScreenPlanner.plantCounts(of: $0) } ?? []
    }

    private var gridCells: [ScreenGridCell] {
        plan.map { ScreenPlanner.cells(of: $0) } ?? []
    }

    private var gridColumns: [GridItem] {
        let count = max(1, plan?.columns ?? ScreenPlanner.Limits.defaultColumns)
        return Array(repeating: GridItem(.flexible(), spacing: 6), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro

                    if let plan, let stats {
                        progressCard(stats: stats)
                        plantPicker
                        gridCard(plan: plan)
                        sizeCard(plan: plan)
                        clearCard(plan: plan)
                        footer
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        Text("The screen could not be opened. Close this and try again.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .growCard(fill: Theme.surfaceSunken, padding: 16)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Screen planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .task { load() }
            .confirmationDialog(
                "Clear the screen?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear the positions", role: .destructive) { clearAll() }
                Button("Keep the positions", role: .cancel) {}
            } message: {
                Text("Every placed branch is emptied. The grid keeps its size and the plants are untouched.")
            }
            .alert(
                "Shrink the screen?",
                isPresented: $showingResizeConfirmation,
                presenting: pendingSize
            ) { size in
                Button("Shrink and remove \(lostPositions)", role: .destructive) {
                    apply(size)
                }
                Button("Keep the size", role: .cancel) {
                    pendingSize = nil
                }
            } message: { _ in
                Text("\(lostPositions) placed branches fall outside the new size and are removed.")
            }
            .alert(
                "The screen was not saved",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                presenting: errorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { text in
                Text(text)
            }
        }
    }

    // MARK: Opening

    private func load() {
        guard plan == nil else { return }
        isLoading = true
        do {
            let opened = try ScreenPlanner.ensurePlan(for: room, in: context)
            plan = opened
            selectedPlantID = plants.first?.persistentModelID
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Screen (SCROG)")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
            Text("Place each branch in the square it sits in. The numbers match the plants below, and tapping a square again empties it. This is your own map — nothing here is measured.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func progressCard(stats: ScreenPlanStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(localized: "\(stats.filled) of \(stats.total)"))
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                Text("positions filled")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                Spacer(minLength: 8)
                Text(stats.percentText)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceSunken)
                    Capsule()
                        .fill(Theme.primary)
                        .frame(width: proxy.size.width * stats.fraction)
                }
            }
            .frame(height: 8)

            if counts.isEmpty {
                Text("No branch is placed yet.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.tertiaryInk)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(counts) { count in
                        legendRow(
                            index: index(of: count.plantID) ?? 0,
                            name: count.name,
                            count: count.count
                        )
                    }
                }
            }
        }
        .growCard()
    }

    private func legendRow(index: Int, name: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(index > 0 ? "\(index)" : "•")
                .font(Theme.sans(11, weight: .semibold))
                .foregroundStyle(Theme.onHero)
                .frame(width: 18, height: 18)
                .background(Circle().fill(tint(for: index)))
            Text(name)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Text(String(localized: "\(count) placed"))
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
        }
        .accessibilityElement(children: .combine)
    }

    private var plantPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                "Place a branch",
                subtitle: plants.isEmpty
                    ? String(localized: "No plants in this room")
                    : String(localized: "Choose the plant whose branch you are placing")
            )

            if plants.isEmpty {
                Text("Add a plant to this room, then its branches can be placed on the screen.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .growCard(fill: Theme.surfaceSunken, padding: 14)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(plants.enumerated()), id: \.element.persistentModelID) { offset, plant in
                            plantChip(plant: plant, index: offset + 1)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .growCard()
    }

    private func plantChip(plant: Plant, index: Int) -> some View {
        let isSelected = plant.persistentModelID == selectedPlantID
        return Button {
            selectedPlantID = plant.persistentModelID
        } label: {
            HStack(spacing: 6) {
                Text("\(index)")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.onHero : Theme.primary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(isSelected ? Theme.onHero.opacity(0.22) : Theme.sageSoft))
                Text(plant.displayName)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.onHero : Theme.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? tint(for: index) : Theme.surfaceSunken))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func gridCard(plan: ScreenPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(
                    "The screen",
                    subtitle: String(localized: "\(plan.columns) × \(plan.rows) squares")
                )
                Spacer(minLength: 8)
                if let selectedPlant {
                    Text(selectedPlant.displayName)
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(gridCells) { cell in
                    Button {
                        place(cell: cell, plan: plan)
                    } label: {
                        ScreenCellPlate(
                            number: cell.plantID.flatMap { index(of: $0) },
                            tint: tint(for: cell.plantID.flatMap { index(of: $0) } ?? 0)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPlant == nil)
                    .accessibilityLabel(label(for: cell))
                    .accessibilityHint(
                        selectedPlant.map {
                            String(localized: "Double-tap to place \($0.displayName)")
                        } ?? String(localized: "Choose a plant first")
                    )
                }
            }
        }
        .growCard()
    }

    private func sizeCard(plan: ScreenPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                "Screen size",
                subtitle: String(localized: "Between \(ScreenPlanner.Limits.minimum) and \(ScreenPlanner.Limits.maximum) squares each way")
            )

            sizeRow(
                title: String(localized: "Columns"),
                value: plan.columns,
                fewer: String(localized: "Fewer columns"),
                more: String(localized: "More columns")
            ) { delta in
                requestSize(columns: plan.columns + delta, rows: plan.rows)
            }

            Divider().overlay(Theme.hairline)

            sizeRow(
                title: String(localized: "Rows"),
                value: plan.rows,
                fewer: String(localized: "Fewer rows"),
                more: String(localized: "More rows")
            ) { delta in
                requestSize(columns: plan.columns, rows: plan.rows + delta)
            }
        }
        .growCard()
    }

    private func sizeRow(
        title: String,
        value: Int,
        fewer: String,
        more: String,
        change: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 12)
            HStack(spacing: 14) {
                Button {
                    change(-1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.surfaceSunken))
                }
                .buttonStyle(.plain)
                .disabled(value <= ScreenPlanner.Limits.minimum)
                .accessibilityLabel(fewer)

                Text("\(value)")
                    .font(Theme.sans(16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 24)

                Button {
                    change(1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.surfaceSunken))
                }
                .buttonStyle(.plain)
                .disabled(value >= ScreenPlanner.Limits.maximum)
                .accessibilityLabel(more)
            }
        }
    }

    private func clearCard(plan: ScreenPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                "Start again",
                subtitle: String(localized: "The size stays; every position is emptied.")
            )

            Button {
                showingClearConfirmation = true
            } label: {
                Text("Clear the screen")
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.danger.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(plan.filledCount == 0)
        }
        .growCard()
    }

    private var footer: some View {
        Text("Your screen plan is stored with this room and never leaves the device. It is a map you keep of where branches sit, not a measurement or a recommendation.")
            .font(Theme.sans(12))
            .foregroundStyle(Theme.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Actions

    private func place(cell: ScreenGridCell, plan: ScreenPlan) {
        guard let selectedPlant else {
            errorMessage = String(localized: "Choose a plant first.")
            return
        }
        do {
            try ScreenPlanner.toggle(
                column: cell.column,
                row: cell.row,
                plant: selectedPlant,
                plan: plan,
                in: context
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestSize(columns: Int, rows: Int) {
        guard let plan else { return }
        let target = ScreenSize(
            columns: ScreenPlanner.clamped(columns),
            rows: ScreenPlanner.clamped(rows)
        )
        guard target != ScreenSize(columns: plan.columns, rows: plan.rows) else { return }

        let lost = ScreenPlanner.filledCountLost(
            resizing: plan,
            columns: target.columns,
            rows: target.rows
        )
        if lost > 0 {
            lostPositions = lost
            pendingSize = target
            showingResizeConfirmation = true
        } else {
            apply(target)
        }
    }

    private func apply(_ size: ScreenSize) {
        guard let plan else { return }
        do {
            try ScreenPlanner.resize(plan, columns: size.columns, rows: size.rows, in: context)
        } catch {
            errorMessage = error.localizedDescription
        }
        pendingSize = nil
    }

    private func clearAll() {
        guard let plan else { return }
        do {
            try ScreenPlanner.clear(plan, in: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Helpers

    /// The number a square carries: the plant's place in this room's list, the
    /// same number the legend and the chips use.
    private func index(of plantID: PersistentIdentifier) -> Int? {
        guard let position = plants.firstIndex(where: { $0.persistentModelID == plantID }) else {
            return nil
        }
        return position + 1
    }

    private func label(for cell: ScreenGridCell) -> String {
        if let name = cell.plantName {
            return String(localized: "Row \(cell.row + 1), column \(cell.column + 1): \(name)")
        }
        return String(localized: "Row \(cell.row + 1), column \(cell.column + 1): empty")
    }

    /// Green throughout, so a screen reads as one canopy rather than a chart.
    private func tint(for index: Int) -> Color {
        let palette: [Color] = [
            Theme.primary,
            Color(hex: 0x5E8C6A),
            Color(hex: 0x8FBE9B),
            Color(hex: 0x3F6E5A),
            Color(hex: 0x6E8F5E),
            Color(hex: 0x24503B),
            Color(hex: 0x7FA07A),
            Color(hex: 0x4C7F63),
            Color(hex: 0x9DBF8E),
            Color(hex: 0x35604A),
            Color(hex: 0x739A6E),
            Color(hex: 0x1F4633)
        ]
        guard index > 0 else { return Theme.secondaryInk }
        return palette[(index - 1) % palette.count]
    }
}

// MARK: - Squares

private struct ScreenCellPlate: View {
    let number: Int?
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(number == nil ? Theme.surfaceSunken : tint)
            .overlay {
                if let number {
                    Text("\(number)")
                        .font(Theme.sans(11, weight: .semibold))
                        .foregroundStyle(Theme.onHero)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            Theme.primary.opacity(0.16),
                            style: StrokeStyle(lineWidth: 1, dash: [2, 3])
                        )
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ScreenSize: Equatable {
    var columns: Int
    var rows: Int
}
