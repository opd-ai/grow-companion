//
//  BackupView.swift
//  Grow Companion
//
//  Password-protected local backup and restore.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppLock.self) private var appLock

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

    @AppStorage(SettingsKey.lastBackupDate) private var lastBackupDate = ""
    @AppStorage(SettingsKey.lastBackupIncludesPhotos) private var lastBackupIncludesPhotos = false
    @State private var includePhotos = true
    @State private var showingCreatePassword = false
    @State private var showingRestorePassword = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var showingRestoreWarning = false
    @State private var backupDocument: ExportDocument?
    @State private var restoreData: Data?
    @State private var restorePassword = ""
    @State private var restoreSummary: ExportService.BackupSummary?
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var showingResult = false

    private var snapshot: ExportSnapshot {
        ExportSnapshot(
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
            counts: DataInventory.counts(in: context)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusCard
                createCard
                restoreCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Backup and restore")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $showingExporter, document: backupDocument, contentType: .data, defaultFilename: "Grow-Companion-Backup") { result in
            if case .failure(let error) = result { showError(error.localizedDescription) }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    restoreData = try Data(contentsOf: url)
                    showingRestorePassword = true
                } catch { showError("The backup could not be read.") }
            case .failure(let error): showError(error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingCreatePassword) {
            BackupPasswordSheet(title: "Protect your backup", subtitle: "Use this password to open the backup later. It cannot be recovered.") { password in
                createBackup(password: password)
            }
        }
        .sheet(isPresented: $showingRestorePassword) {
            BackupPasswordSheet(title: "Unlock backup", subtitle: "Enter the password used when this backup was created.") { password in
                validateRestore(password: password)
            }
        }
        .confirmationDialog("Replace this device's records?", isPresented: $showingRestoreWarning, titleVisibility: .visible) {
            Button("Restore and replace", role: .destructive) { restore() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(restoreWarning)
        }
        .alert("Backup problem", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(resultTitle, isPresented: $showingResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }

    private var restoreWarning: String {
        guard let restoreSummary else {
            return "Restoring replaces the records currently on this device. This cannot be undone."
        }
        let photos = restoreSummary.includesPhotos ? " with journal photos" : ""
        let manifest = restoreSummary.version >= 2
            ? "\(restoreSummary.totalRecords) records"
            : "an older backup with no record manifest"
        return "This backup holds \(manifest) (format version \(restoreSummary.version)\(photos)). Restoring replaces the records currently on this device and cannot be undone."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Backup and restore")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Keep a protected copy of your grow record.")
                .font(Theme.sans(15))
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: lastBackupDate.isEmpty ? "externaldrive.badge.plus" : "checkmark.shield.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.onHero)
                .frame(width: 62, height: 62)
                .background(Circle().fill(Theme.onHero.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(lastBackupDate.isEmpty ? "No backup created yet" : "Backup created \(lastBackupDate)")
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.onHero)
                Text(lastBackupDate.isEmpty ? "Your records stay on this device until you choose to export a backup." : "Password protected · \(lastBackupIncludesPhotos ? "journal photos included" : "journal photos not included")")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.onHero.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard(fill: Theme.primary, padding: 18)
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create a backup").font(Theme.serif(26)).foregroundStyle(Theme.ink)
            backupRow(icon: "doc.text", title: "Grow records", detail: "Every record type the app stores, with a count manifest") { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary) }
            Divider().overlay(Theme.hairline)
            HStack(spacing: 12) {
                Image(systemName: "photo").foregroundStyle(Theme.primary).frame(width: 32, height: 32).background(Circle().fill(Theme.sageSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Journal photos").font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("Include photos from your journal").font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                }
                Spacer()
                Toggle("", isOn: $includePhotos)
                    .labelsHidden()
                    .tint(Theme.primary)
                    .accessibilityLabel("Include journal photos")
            }
            Divider().overlay(Theme.hairline)
            backupRow(icon: "lock", title: "Password protection", detail: "Secure your backup with a password") { HStack(spacing: 6) { Text("Required").font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk); Image(systemName: "chevron.right").foregroundStyle(Theme.tertiaryInk) } }
            PrimaryButton("Create protected backup", systemImage: "externaldrive.badge.plus") { showingCreatePassword = true }
        }
        .growCard()
    }

    private var restoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restore").font(Theme.serif(26)).foregroundStyle(Theme.ink)
            Text("Restoring replaces the records currently on this device. The backup is checked in a temporary store before anything here is touched.")
                .font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton("Choose backup from Files", systemImage: "folder") { showingImporter = true }
        }
        .growCard()
    }

    private func backupRow<Accessory: View>(icon: String, title: String, detail: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.primary).frame(width: 32, height: 32).background(Circle().fill(Theme.sageSoft))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
            }
            Spacer()
            accessory()
        }
    }

    private func createBackup(password: String) {
        do {
            let data = try ExportService.buildBackup(
                snapshot: snapshot,
                includeJournal: true,
                includePhotos: includePhotos,
                password: password
            )
            backupDocument = ExportDocument(data: data)
            lastBackupDate = Format.shortDate(Date())
            lastBackupIncludesPhotos = includePhotos
            showingExporter = true
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func validateRestore(password: String) {
        guard let restoreData else { return }
        do {
            let root = try ExportService.decodeBackup(restoreData, password: password)
            try BackupService.validate(root)
            restoreSummary = try ExportService.summarize(root)
            restorePassword = password
            showingRestoreWarning = true
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func restore() {
        guard let restoreData, !restorePassword.isEmpty else { return }
        defer {
            restorePassword = ""
            restoreSummary = nil
        }
        do {
            let root = try ExportService.decodeBackup(restoreData, password: restorePassword)
            let report = try BackupService.restore(root, context: context, appLock: appLock)
            self.restoreData = nil
            resultTitle = "Backup restored"
            resultMessage = "\(report.totalInserted) records were restored from backup version \(report.backupVersion)."
            showingResult = true
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
