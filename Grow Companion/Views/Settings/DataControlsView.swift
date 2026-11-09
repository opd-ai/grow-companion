//
//  DataControlsView.swift
//  Grow Companion
//
//  Export the records the grower chooses to a ZIP in the Files app, and the
//  double-confirmed route to erasing everything on the device. The manifest is
//  built from the same model inventory that export and delete walk, so what the
//  screen says it will take or remove is what actually happens.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataControlsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppLock.self) private var appLock
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \Strain.name) private var strains: [Strain]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journal: [JournalEntry]
    @Query(sort: \CareReminder.nextDueDate) private var reminders: [CareReminder]
    @Query(sort: \DryingSession.startedAt, order: .reverse) private var dryingSessions: [DryingSession]
    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]
    @Query(sort: \FeedSchedule.name) private var feedSchedules: [FeedSchedule]
    @Query(sort: \CycleArchive.completedAt, order: .reverse) private var cycleArchives: [CycleArchive]
    @Query(sort: \SensorDevice.name) private var sensors: [SensorDevice]
    @Query(sort: \ShareGrant.createdAt, order: .reverse) private var shareGrants: [ShareGrant]
    @Query(sort: \ComplianceSnapshot.capturedAt, order: .reverse)
    private var complianceSnapshots: [ComplianceSnapshot]
    @Query(sort: \RuleEvaluationEvent.evaluatedAt, order: .reverse)
    private var ruleEvaluationEvents: [RuleEvaluationEvent]
    @Query(sort: \GrowGoal.updatedAt, order: .reverse) private var goals: [GrowGoal]
    @Query(sort: \GrowerBreeder.name) private var breeders: [GrowerBreeder]

    @State private var includeJournal = false
    @State private var includePhotos = false
    @State private var protectExport = false
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var recordCounts: [String: Int] = [:]

    @State private var exportDocument: ExportDocument?
    @State private var exportContentType: UTType = .zip
    @State private var exportFileName = "Grow Companion Export"
    @State private var showingExporter = false

    @State private var exportResultTitle = "Export"
    @State private var exportResultMessage = ""
    @State private var showingExportResult = false

    @State private var deletionResultTitle = ""
    @State private var deletionResultMessage = ""
    @State private var showingDeletionResult = false

    @State private var showingFirstConfirm = false
    @State private var showingEraseSheet = false

    private var photoCount: Int {
        journal.filter { $0.photoFileName != nil }.count
    }

    private var totalRecords: Int {
        DataInventory.total(of: recordCounts)
    }

    private var canExport: Bool {
        if protectExport {
            return password.count >= 6 && password == confirmPassword
        }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Export and delete")
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.ink)
                    Text("Take a copy with you, or remove every record this app keeps.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                exportCard
                deleteCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Export and delete")
        .navigationBarTitleDisplayMode(.inline)
        .task { refreshCounts() }
        .onChange(of: includeJournal) { _, included in
            if !included { includePhotos = false }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                exportResultTitle = "Export saved"
                exportResultMessage = "The archive is in the Files app under the name you chose. Files copies are outside this app and are not removed by delete-all."
            case .failure(let error):
                exportResultTitle = "Export failed"
                exportResultMessage = error.localizedDescription
            }
            showingExportResult = true
        }
        .alert(exportResultTitle, isPresented: $showingExportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportResultMessage)
        }
        .alert(deletionResultTitle, isPresented: $showingDeletionResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionResultMessage)
        }
        .confirmationDialog(
            "Delete all data?",
            isPresented: $showingFirstConfirm,
            titleVisibility: .visible
        ) {
            Button("Continue", role: .destructive) {
                showingEraseSheet = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every record on this device. You will be asked to type a phrase to confirm.")
        }
        .sheet(isPresented: $showingEraseSheet) {
            DeleteEverythingSheet(summary: eraseSummary) {
                eraseEverything()
            }
        }
    }

    // MARK: Export

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Export", subtitle: "A copy you keep")

            Text("The archive holds a JSON file with a record-count manifest, CSV files you can open in a spreadsheet, and a photos folder when the journal is included.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            manifest

            Toggle(isOn: $includeJournal) {
                label("Cultivation journal entries", subtitle: "Notes, observations and the photos attached to them")
            }
            .tint(Theme.primary)
            .accessibilityHint("Adds the cultivation journal to the export")

            Toggle(isOn: $includePhotos) {
                label("Journal photos", subtitle: "Full-size images, without any location data")
            }
            .tint(Theme.primary)
            .disabled(!includeJournal)
            .opacity(includeJournal ? 1 : 0.5)
            .accessibilityHint("Adds the imported journal photos to the export")

            Divider().overlay(Theme.hairline)

            Toggle(isOn: $protectExport) {
                label("Password protection", subtitle: "Encrypts the archive with AES-256 and a password you choose")
            }
            .tint(Theme.primary)
            .accessibilityHint("Encrypts the archive with AES-256 and a password")

            if protectExport {
                SecureField("Password (6 characters or more)", text: $password)
                    .textFieldStyle(.plain)
                    .font(Theme.sans(16))
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )

                SecureField("Repeat the password", text: $confirmPassword)
                    .textFieldStyle(.plain)
                    .font(Theme.sans(16))
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )

                if !password.isEmpty && password.count < 6 {
                    Text("Use at least six characters.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.amber)
                } else if !confirmPassword.isEmpty && password != confirmPassword {
                    Text("The two passwords do not match.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.amber)
                }

                Text("The protected file is saved as .data and opens with the password. It cannot be recovered if the password is lost.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryButton("Create export", systemImage: "square.and.arrow.up", isEnabled: canExport) {
                createExport()
            }
            .accessibilityLabel("Export cultivation records")
            .accessibilityHint("Creates the archive with the categories and counts shown above")
        }
        .growCard()
    }

    private var manifest: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Record manifest")
                    .font(Theme.sans(11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryInk)
                Spacer(minLength: 8)
                Text("format v\(ExportService.currentFormatVersion)")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryInk)
            }

            InfoRow(label: "Records included", value: "\(totalRecords)")
            InfoRow(label: "Journal entries", value: "\(journal.count)")
            InfoRow(label: "Journal photos", value: "\(photoCount)")

            let entries = DataInventory.nonEmpty(from: recordCounts)
            if entries.isEmpty {
                Text("There are no records yet. An empty grow exports a zero-count manifest.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(entries) { entry in
                    InfoRow(label: entry.label, value: "\(entry.count)")
                }
            }

            Text("Photos are included only when you choose them. No location data is written into the archive.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14)
        .accessibilityElement(children: .contain)
    }

    private func label(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func createExport() {
        do {
            let payload = try ExportService.build(
                snapshot: ExportSnapshot(
                    profile: profiles.first,
                    rooms: rooms,
                    plants: plants,
                    strains: strains,
                    reminders: reminders,
                    dryingSessions: dryingSessions,
                    journal: journal,
                    feedSchedules: feedSchedules,
                    cycleArchives: cycleArchives,
                    sensors: sensors,
                    shareGrants: shareGrants,
                    complianceSnapshots: complianceSnapshots,
                    ruleEvaluationEvents: ruleEvaluationEvents,
                    goals: goals,
                    breeders: breeders,
                    counts: recordCounts.isEmpty ? DataInventory.counts(in: context) : recordCounts
                ),
                options: ExportOptions(
                    includeJournal: includeJournal,
                    includePhotos: includePhotos,
                    password: protectExport ? password : nil
                )
            )

            exportFileName = payload.fileName
            exportContentType = payload.isEncrypted ? .data : .zip
            exportDocument = ExportDocument(data: payload.data)
            showingExporter = true
        } catch {
            exportResultTitle = "Export failed"
            exportResultMessage = error.localizedDescription
            showingExportResult = true
        }
    }

    // MARK: Delete

    private var deleteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Delete everything", subtitle: "No undo")

            Text("Removes every record type the app stores, its journal photos and thumbnails, pending notifications, and the app lock and notification preferences.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("Copies you exported to Files, copies inside a device or iCloud backup, and screenshots are outside this app and are not removed here.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showingFirstConfirm = true
            } label: {
                Text("Delete all data")
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.dangerSoft)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete local records")
            .accessibilityHint("Asks you to type a phrase before anything is removed")
        }
        .growCard()
    }

    private var eraseSummary: [String] {
        var lines = DataInventory.nonEmpty(from: recordCounts).map { entry in
            "\(entry.label): \(entry.count)"
        }
        lines.append("Journal photos and their thumbnails")
        lines.append("Every pending notification")
        lines.append("Device encryption keys")
        lines.append("App lock, notification and unit preferences")
        return lines
    }

    private func refreshCounts() {
        recordCounts = DataInventory.counts(in: context)
    }

    private func eraseEverything() {
        let before = totalRecords
        do {
            let remaining = try ExportService.deleteEverything(context: context, appLock: appLock)
            let leftover = DataInventory.total(of: remaining)
            refreshCounts()

            deletionResultTitle = leftover == 0 ? "Local records deleted" : "Delete did not finish"
            deletionResultMessage = leftover == 0
                ? "\(before) records were removed from this device, along with journal photos, notifications and app preferences. Copies in Files, device backups and iCloud backups are outside the app and are not removed here."
                : "\(leftover) records remain on this device. Copies in Files, device backups and iCloud backups were not touched. Try again, and contact support if it keeps happening."
        } catch {
            deletionResultTitle = "Delete failed"
            deletionResultMessage = "\(error.localizedDescription) Your records were kept."
            refreshCounts()
        }
        showingDeletionResult = true
        showingFirstConfirm = false
    }
}

// MARK: - Erase confirmation

struct DeleteEverythingSheet: View {
    let summary: [String]
    let onErase: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phrase = ""

    private let requiredPhrase = "DELETE EVERYTHING"

    private var canErase: Bool {
        phrase.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == requiredPhrase
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("This cannot be undone")
                            .font(Theme.serif(26))
                            .foregroundStyle(Theme.ink)
                        Text("Everything below is removed from this device. Copies you exported to Files and copies in device or iCloud backups stay where they are.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(summary.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.danger)
                                    .padding(.top, 2)
                                Text(line)
                                    .font(Theme.sans(13))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 8)

                            if index != summary.count - 1 {
                                Divider().overlay(Theme.hairline)
                            }
                        }
                    }
                    .growCard(padding: 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type \(requiredPhrase) to confirm")
                            .font(Theme.sans(11, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.secondaryInk)
                        TextField(requiredPhrase, text: $phrase)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.plain)
                            .font(Theme.sans(16))
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.surfaceSunken)
                            )
                    }

                    Button {
                        dismiss()
                        onErase()
                    } label: {
                        Text("Erase everything")
                            .font(Theme.sans(17, weight: .semibold))
                            .foregroundStyle(Theme.onHero)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(canErase ? Theme.danger : Theme.danger.opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canErase)
                    .accessibilityHint("Deletes the local records listed above")

                    SecondaryButton("Keep my data") {
                        dismiss()
                    }
                }
                .padding(20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - File document

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip, .data] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
