//
//  GrowReportView.swift
//  Grow Companion
//
//  Builds the local PDF grow report and hands it to the system share sheet.
//  Copies shared or saved leave the app's control, which the screen says.
//

import SwiftUI
import SwiftData
import os

struct GrowReportView: View {
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journal: [JournalEntry]

    @AppStorage(SettingsKey.unitSystem) private var unitRaw = "metric"
    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8

    @State private var includeJournal = false
    @State private var reportURL: URL?
    @State private var generatedSize = 0
    @State private var errorMessage = ""
    @State private var showingError = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GrowCompanion",
        category: "GrowReport"
    )

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .metric }
    private var profile: GrowProfile? { profiles.first }
    private var rule: JurisdictionRule? { profile?.rule }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCard
                journalCard
                generateCard
                scopeCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Grow report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("Could not create the report", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: includeJournal) { _, _ in
            reportURL = nil
            generatedSize = 0
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A printable summary")
                .font(Theme.serif(28))
                .foregroundStyle(Theme.ink)
            Text("One PDF made on this device from your existing records: stages, care, training, treatments, scouting, harvest and the compliance estimate with its rule pack.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("What this report covers")
            InfoRow(label: "Plants", value: "\(plants.count)")
            InfoRow(label: "Rooms", value: "\(rooms.count)")
            InfoRow(label: "Harvest records", value: "\(harvestCount)")
            InfoRow(label: "Rule pack", value: "\(RulePack.version) · \(RulePack.displayDate(RulePack.verifiedOn))")
            InfoRow(
                label: "Jurisdiction",
                value: profile?.jurisdictionLabel.isEmpty == false
                    ? profile?.jurisdictionLabel ?? "Not set"
                    : "Not set"
            )
        }
        .growCard(padding: 16)
    }

    private var harvestCount: Int {
        plants.filter {
            $0.wetWeightGrams != nil || $0.dryWeightGrams != nil || $0.harvestDisposition != nil
        }.count
    }

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Journal")
            Toggle("Include cultivation journal entries", isOn: $includeJournal)
                .tint(Theme.primary)
                .font(Theme.sans(14))
            Text("Off by default. Journal text is included only when you turn this on, and photos are never embedded. This app has no personal effect journal to include.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(padding: 16)
    }

    private var generateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let reportURL {
                ShareLink(item: reportURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Share or save the PDF")
                            .font(Theme.sans(16, weight: .semibold))
                    }
                    .foregroundStyle(Theme.onHero)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.primary)
                    )
                }
                .accessibilityLabel("Share or save the grow report PDF")

                Text("PDF ready · \(max(1, generatedSize / 1024)) KB")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryInk)

                Text("Copies you share or save are outside this app and are not removed by delete-all.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                PrimaryButton("Create PDF", systemImage: "doc.text") {
                    generate()
                }
            }

            Text("The filename is neutral and carries no plant, room or strain name.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(padding: 16)
    }

    private var scopeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("What the report states")
            Text("The compliance page names the rule pack, the date its rules were last updated and the verification duty. Dispositions are described only as retained, consumed at home or destroyed.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(LegalCopy.verificationDuty)
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(padding: 16)
    }

    private func generate() {
        let data = GrowReportService.makeData(
            plants: plants,
            rooms: rooms,
            profile: profile,
            journal: journal,
            rule: rule,
            warningThreshold: warningThreshold,
            unit: unit,
            includeJournal: includeJournal
        )

        do {
            let pdf = GrowReportRenderer.pdf(from: data)
            let fileName = GrowReportRenderer.fileName(for: data.generatedAt)
            let url = try GrowReportRenderer.writeTemporaryFile(pdf: pdf, fileName: fileName)
            reportURL = url
            generatedSize = pdf.count
        } catch {
            logger.error(
                "Grow report PDF failed: \(error.localizedDescription, privacy: .public)"
            )
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
