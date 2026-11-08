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

    @AppStorage("lastBackupDate") private var lastBackupDate = ""
    @AppStorage("lastBackupIncludesPhotos") private var lastBackupIncludesPhotos = false
    @State private var includePhotos = true
    @State private var showingCreatePassword = false
    @State private var showingRestorePassword = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var showingRestoreWarning = false
    @State private var backupDocument: ExportDocument?
    @State private var restoreData: Data?
    @State private var restorePassword = ""
    @State private var errorMessage = ""
    @State private var showingError = false

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
            Text("Restoring replaces the records currently on this device. This cannot be undone.")
        }
        .alert("Backup problem", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
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
            backupRow(icon: "doc.text", title: "Grow records", detail: "Always included") { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary) }
            Divider().overlay(Theme.hairline)
            HStack(spacing: 12) {
                Image(systemName: "photo").foregroundStyle(Theme.primary).frame(width: 32, height: 32).background(Circle().fill(Theme.sageSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Journal photos").font(Theme.sans(15, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("Include photos from your journal").font(Theme.sans(12)).foregroundStyle(Theme.secondaryInk)
                }
                Spacer()
                Toggle("", isOn: $includePhotos).labelsHidden().tint(Theme.primary)
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
            Text("Restoring replaces the records currently on this device.")
                .font(Theme.sans(13)).foregroundStyle(Theme.secondaryInk)
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
            let data = try ExportService.buildBackup(profile: profiles.first, rooms: rooms, plants: plants, strains: strains, reminders: reminders, dryingSessions: dryingSessions, journal: journal, includePhotos: includePhotos, password: password)
            backupDocument = ExportDocument(data: data)
            lastBackupDate = Format.shortDate(Date())
            lastBackupIncludesPhotos = includePhotos
            showingExporter = true
        } catch { showError("The protected backup could not be created.") }
    }

    private func validateRestore(password: String) {
        guard let restoreData else { return }
        do {
            _ = try ExportService.decodeBackup(restoreData, password: password)
            restorePassword = password
            showingRestoreWarning = true
        } catch { showError("That password is incorrect or the backup is invalid.") }
    }

    private func restore() {
        guard let restoreData, !restorePassword.isEmpty else { return }
        defer { restorePassword = "" }
        do {
            let root = try ExportService.decodeBackup(restoreData, password: restorePassword)
            try BackupService.restore(root, context: context, appLock: appLock)
            self.restoreData = nil
        } catch { showError("The backup could not be restored. Your current records were not changed safely.") }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
