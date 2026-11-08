//
//  DataControlsView.swift
//  Grow Companion
//
//  Export the records the grower chooses to a ZIP in the Files app, and the
//  double-confirmed route to erasing everything on the device.
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
    @Query private var scoutingChecks: [ScoutingCheck]

    @State private var includeJournal = false
    @State private var includePhotos = false
    @State private var protectExport = false
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var exportDocument: ExportDocument?
    @State private var exportContentType: UTType = .zip
    @State private var exportFileName = "Grow Companion Export"
    @State private var showingExporter = false

    @State private var exportResultTitle = "Export"
    @State private var exportResultMessage = ""
    @State private var showingExportResult = false

    @State private var showingFirstConfirm = false
    @State private var showingEraseSheet = false

    private var photoCount: Int {
        journal.filter { $0.photoFileName != nil }.count
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
                exportResultMessage = "The archive is in the Files app under the name you chose."
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

            Text("The archive holds a JSON file with everything in it, CSV files you can open in a spreadsheet, and a photos folder when the journal is included.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                InfoRow(label: "Profile, rooms, plants and logs", value: "Always included")
                InfoRow(label: "Plants", value: "\(plants.count)")
                InfoRow(label: "Rooms", value: "\(rooms.count)")
                InfoRow(label: "Strains", value: "\(strains.count)")
                InfoRow(label: "Journal entries", value: "\(journal.count)")
            }
            .growCard(fill: Theme.surfaceSunken, padding: 14)

            Toggle(isOn: $includeJournal) {
                label("Journal entries", subtitle: "Notes, observations and the photos attached to them")
            }
            .tint(Theme.primary)

            Toggle(isOn: $includePhotos) {
                label("Journal photos", subtitle: "Full-size images, without any location data")
            }
            .tint(Theme.primary)
            .disabled(!includeJournal)
            .opacity(includeJournal ? 1 : 0.5)

            Divider().overlay(Theme.hairline)

            Toggle(isOn: $protectExport) {
                label("Password protection", subtitle: "Encrypts the archive with AES-256 and a password you choose")
            }
            .tint(Theme.primary)

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
        }
        .growCard()
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
                profile: profiles.first,
                rooms: rooms,
                plants: plants,
                strains: strains,
                reminders: reminders,
                dryingSessions: dryingSessions,
                journal: journal,
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

            Text("Removes the grow profile, rooms, plants and their stage history, journal entries and photos, strains, harvest and curing records, care reminders and their notifications, and the app lock settings.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
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
        }
        .growCard()
    }

    private var eraseSummary: [String] {
        [
            "\(plants.count) plant\(plants.count == 1 ? "" : "s") and their stage history",
            "\(rooms.count) room\(rooms.count == 1 ? "" : "s") with environment, feed and calibration logs",
            "\(strains.count) strain\(strains.count == 1 ? "" : "s") and their harvest ratings",
            "\(journal.count) journal entr\(journal.count == 1 ? "y" : "ies") and \(photoCount) photo\(photoCount == 1 ? "" : "s")",
            "Drying and curing sessions with their checks and burps",
            "\(scoutingChecks.count) scouting check\(scoutingChecks.count == 1 ? "" : "s")",
            "Equipment, treatment and service history",
            "\(reminders.count) care reminder\(reminders.count == 1 ? "" : "s") and every pending notification",
            "Your grow profile and the onboarding answers",
            "App lock settings and notification preferences"
        ]
    }

    private func eraseEverything() {
        ExportService.deleteEverything(context: context, appLock: appLock)
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
                        Text("Everything below is removed from this device. There is no backup unless you exported one.")
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
                        onErase()
                        dismiss()
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
