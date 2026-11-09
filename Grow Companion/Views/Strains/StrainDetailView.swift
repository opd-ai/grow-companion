//
//  StrainDetailView.swift
//  Grow Companion
//
//  One cultivar: the breeder's figures, what the grower's own finished cycles
//  did, the plants growing it and how its harvests were rated.
//

import SwiftUI
import SwiftData

struct StrainDetailView: View {
    @Bindable var strain: Strain

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \GrowerBreeder.name) private var storedBreeders: [GrowerBreeder]

    @State private var showingEditor = false
    @State private var showingDeleteConfirm = false

    private var observations: [FloweringObservation] {
        StrainInsights.observations(for: strain)
    }

    private var average: (days: Double, count: Int)? {
        StrainInsights.observedAverage(for: strain)
    }

    private var breederProfile: BreederProfile? {
        BreederLibrary.profile(named: strain.displayBreeder, stored: storedBreeders)
    }

    private var lineage: CultivarLineage? {
        BreederLibrary.lineage(for: strain)
    }

    private var displayedParentLines: String? {
        let entered = strain.parentLines.trimmingCharacters(in: .whitespacesAndNewlines)
        return entered.isEmpty ? lineage?.parentLines : entered
    }

    private var displayedClaimedYield: String? {
        let entered = strain.claimedYield.trimmingCharacters(in: .whitespacesAndNewlines)
        return entered.isEmpty ? lineage?.claimedYield : entered
    }

    /// The status the card shows: the strain's own entry when it has one, then
    /// the bundled claim for the same cultivar and breeder.
    private var effectiveLineageStatus: LineageStatus {
        if strain.lineageStatus != .missing { return strain.lineageStatus }
        return lineage?.lineageStatus ?? .missing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                breederContextCard
                timingCard
                if !strain.ratedPlants.isEmpty { ratingsCard }
                if !strain.sortedPlants.isEmpty { plantsCard }
                notesCard
                dangerZone
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(strain.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .sheet(isPresented: $showingEditor) {
            StrainEditorView(strain: strain)
        }
        .confirmationDialog(
            "Delete this strain?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete strain", role: .destructive) {
                deleteStrain()
            }
            Button("Keep strain", role: .cancel) {}
        } message: {
            Text("Its plants stay and keep the name they were assigned under. Ratings and tasting notes entered on those plants are kept too.")
        }
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(strain.displayName)
                    .font(Theme.serif(28))
                    .foregroundStyle(Theme.ink)
                Text(strain.displayBreeder)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryInk)
            }

            HStack(spacing: 8) {
                Pill(text: strain.type.title, systemImage: strain.type.systemImage)
                Pill(
                    text: String(localized: "\(strain.floweringLabel) claimed"),
                    systemImage: "calendar",
                    tint: Theme.secondaryInk,
                    fill: Theme.surfaceSunken
                )
                if let rating = strain.averageRating {
                    Pill(
                        text: "\(String(format: "%.1f", rating)) / 5",
                        systemImage: "star.fill",
                        tint: Theme.secondaryInk,
                        fill: Theme.surfaceSunken
                    )
                }
            }

            Text("\(String(localized: "\(strain.plants.count) plant\(strain.plants.count == 1 ? "" : "s") recorded")) · \(String(localized: "\(observations.count) finished cycle\(observations.count == 1 ? "" : "s")"))")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    // MARK: Breeder context

    private var breederContextCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader("Breeder context", subtitle: "Reference material kept separate from your results")

            if let breederProfile {
                NavigationLink {
                    BreederProfileView(name: breederProfile.name)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(breederProfile.name)
                                .font(Theme.sans(15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(breederProfile.summary)
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(breederProfile.source)
                                .font(Theme.sans(10, weight: .semibold))
                                .foregroundStyle(Theme.tertiaryInk)
                        }
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryInk)
                            .padding(.top, 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "View the \(breederProfile.name) reference profile"))
            } else {
                statusRow(icon: "person.crop.circle", title: "Breeder profile", value: "No shared profile available", tint: Theme.amber)
            }

            Divider().overlay(Theme.hairline)
            contextRow("Parent lines", displayedParentLines ?? "Not documented", icon: "arrow.triangle.branch", warning: displayedParentLines == nil)
            contextRow("Claimed yield", displayedClaimedYield ?? "Not provided", icon: "chart.bar.xaxis", warning: displayedClaimedYield == nil)
            contextRow("Lineage status", effectiveLineageStatus.title, icon: effectiveLineageStatus.systemImage, warning: effectiveLineageStatus != .documented)

            if effectiveLineageStatus == .disputed {
                Text(BreederLibrary.lineageCaveat)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Breeder figures are claims from reference material, not verified results. Your observed flowering time, yield, rating and notes below come only from your own grow.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.amberSoft))
        }
        .growCard()
    }

    private func contextRow(_ title: String, _ value: String, icon: String, warning: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(warning ? Theme.amber : Theme.primary)
                .frame(width: 18)
            Text(title)
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(warning ? Theme.amber : Theme.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.sans(14, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(value).font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
            }
        }
    }

    // MARK: Timing

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Flowering time", subtitle: "The breeder's figure beside your own")

            HStack(alignment: .top, spacing: 16) {
                metric(
                    String(localized: "Claimed"),
                    strain.floweringLabel,
                    detail: String(localized: "Breeder's claim")
                )
                metric(
                    "Observed",
                    average.map { StrainInsights.shortLengthText(days: $0.days) } ?? "—",
                    detail: average.map { "\($0.count) finished cycle\($0.count == 1 ? "" : "s")" } ?? "No finished cycle yet"
                )
            }

            if let average {
                Text(deltaText(average.days))
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Flower-week counters use the breeder's \(strain.floweringLabel) until one of your own cycles finishes. After that, your observed figure takes over.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )
            }
        }
        .growCard()
    }

    private func deltaText(_ days: Double) -> String {
        let difference = Int(days.rounded()) - strain.expectedFloweringDays
        if difference == 0 {
            return String(localized: "Your observed average matches the breeder's figure, and flower-week counters use it now.")
        }
        let amount = Format.dayCount(abs(difference))
        if difference > 0 {
            return String(localized: "Your own cycles took \(amount) longer than the breeder's figure. Flower-week counters now use your observed \(StrainInsights.shortLengthText(days: days)).")
        }
        return String(localized: "Your own cycles finished \(amount) faster than the breeder's figure. Flower-week counters now use your observed \(StrainInsights.shortLengthText(days: days)).")
    }

    private func metric(_ label: String, _ value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.sans(10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(Theme.tertiaryInk)
            Text(value)
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            if let detail {
                Text(detail)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Ratings

    private var ratingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Your results", subtitle: "Rated after harvest and cure")

            if let rating = strain.averageRating {
                HStack(spacing: 10) {
                    StarRatingView(rating: Int(rating.rounded()), size: 14)
                    Text("\(String(format: "%.1f", rating)) average from \(strain.ratedPlants.count) harvest\(strain.ratedPlants.count == 1 ? "" : "s")")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                }
            }

            VStack(spacing: 0) {
                ForEach(strain.ratedPlants) { plant in
                    NavigationLink {
                        PlantDetailView(plant: plant)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(plant.displayName)
                                    .font(Theme.sans(14, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Spacer(minLength: 8)
                                StarRatingView(rating: plant.rating ?? 0, size: 10)
                            }
                            if !plant.tastingNotes.isEmpty {
                                Text(plant.tastingNotes)
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.secondaryInk)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let ratedAt = plant.ratedAt {
                                Text("Rated \(Format.shortDate(ratedAt))")
                                    .font(Theme.sans(11))
                                    .foregroundStyle(Theme.tertiaryInk)
                            }
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if plant.id != strain.ratedPlants.last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }
        .growCard(padding: 16)
    }

    // MARK: Plants

    private var plantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Plants", subtitle: "Every plant assigned to this strain")

            VStack(spacing: 0) {
                ForEach(strain.sortedPlants) { plant in
                    NavigationLink {
                        PlantDetailView(plant: plant)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.sageSoft)
                                    .frame(width: 32, height: 32)
                                Image(systemName: plant.stage.systemImage)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.primary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plant.displayName)
                                    .font(Theme.sans(14, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(plantDetail(plant))
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                            Spacer(minLength: 6)
                            StageBadge(stage: plant.stage)
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if plant.id != strain.sortedPlants.last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
        }
        .growCard(padding: 16)
    }

    private func plantDetail(_ plant: Plant) -> String {
        if let days = StrainInsights.floweringDays(for: plant) {
            return String(localized: "Flowered \(StrainInsights.shortLengthText(days: Double(days))) · \(plant.stage.title)")
        }
        if plant.stage == .flower {
            return String(localized: "Flower week \(StrainInsights.currentFlowerWeek(for: plant)) · day \(plant.daysInStage)")
        }
        return String(localized: "\(Format.dayCount(plant.daysInStage)) in \(plant.stage.title)")
    }

    // MARK: Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Notes")
            TextEditor(text: $strain.notes)
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
                    if strain.notes.isEmpty {
                        Text("Anything worth repeating about this cultivar")
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

    // MARK: Danger zone

    private var dangerZone: some View {
        Button {
            showingDeleteConfirm = true
        } label: {
            Text("Delete this strain")
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func deleteStrain() {
        context.delete(strain)
        try? context.save()
        dismiss()
    }
}
