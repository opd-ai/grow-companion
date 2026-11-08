//
//  SharingView.swift
//  Grow Companion
//
//  Protected, recipient-scoped sharing: a share code identifies this device, a
//  sealed file carries only the chosen categories, and a received file is opened
//  read-only after its sender is verified. There is no server in this flow.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct SharingView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \ShareGrant.createdAt, order: .reverse) private var grants: [ShareGrant]
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \GrowProfile.createdAt, order: .reverse) private var profiles: [GrowProfile]

    @AppStorage(SettingsKey.warningThreshold) private var warningThreshold: Double = 0.8

    private let service = SharePackageService()

    @State private var shareCode: String?
    @State private var copied = false
    @State private var removingCode = false
    @State private var showingCreate = false
    @State private var showingImporter = false
    @State private var showingOpenSheet = false
    @State private var pendingData: Data?
    @State private var revoking: ShareGrant?
    @State private var errorMessage: String?
    @State private var showingError = false

    private var source: SharePayloadBuilder.Source {
        SharePayloadBuilder.Source(
            profile: profiles.first,
            rooms: rooms,
            plants: plants,
            rule: profiles.first?.rule,
            warningThreshold: warningThreshold
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                shareCodeCard
                createCard
                openCard
                if !grants.isEmpty {
                    sharesCard
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { refreshCode() }
        .sheet(isPresented: $showingCreate) {
            CreateShareView(source: source) { copied = false }
        }
        .sheet(isPresented: $showingOpenSheet) {
            if let pendingData {
                OpenShareSheet(data: pendingData)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .confirmationDialog(
            "Revoke this share?",
            isPresented: Binding(
                get: { revoking != nil },
                set: { if !$0 { revoking = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Revoke access", role: .destructive) {
                if let revoking { revoke(revoking) }
                revoking = nil
            }
            Button("Keep share", role: .cancel) { revoking = nil }
        } message: {
            Text("This records the revocation here. A file you already sent can still be opened by its recipient until it expires.")
        }
        .alert("Sharing problem", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sharing")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Give one person a scoped, read-only view. Files are encrypted on this device and handed over by you.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shareCodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Your share code", subtitle: "Send it to the person you share with")

            if let shareCode {
                Text(shareCode)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )
                    .accessibilityLabel("Your share code")

                HStack(spacing: 10) {
                    SecondaryButton(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
                        UIPasteboard.general.string = shareCode
                        copied = true
                    }

                    SecondaryButton("Remove", systemImage: "trash") {
                        removingCode = true
                    }
                }

                Text("This code is public information, not a secret. It tells another device how to address a share to you and how to verify what you send.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Create a key pair on this device to get a share code. The private half stays in the Keychain and is never sent anywhere.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton("Create my share code", systemImage: "key") {
                    createCode()
                }
            }
        }
        .growCard()
        .confirmationDialog(
            "Remove your share code?",
            isPresented: $removingCode,
            titleVisibility: .visible
        ) {
            Button("Remove share code", role: .destructive) { removeCode() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Shares addressed to this code can no longer be opened on this device. Your records are untouched.")
        }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Create a share", subtitle: "Choose scope, categories and expiry")
            Text("You pick the rooms, plants and categories. The cultivation journal, photos and your county are never included.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(
                "Choose scope and prepare",
                systemImage: "lock.rectangle",
                isEnabled: shareCode != nil
            ) {
                showingCreate = true
            }
        }
        .growCard()
    }

    private var openCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Open a shared grow", subtitle: "Read-only")
            Text("Open a file someone sent you. You will be asked for their share code so the app can verify who created it before showing anything.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryButton("Open a shared file", systemImage: "folder") {
                showingImporter = true
            }
        }
        .growCard()
    }

    private var sharesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Shares you created", subtitle: "Records on this device only")

            ForEach(grants) { grant in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(grant.recipientName.isEmpty ? "Unnamed recipient" : grant.recipientName)
                                .font(Theme.sans(15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text("\(grant.scopeSummary) · expires \(Format.shortDate(grant.expiresAt))")
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Pill(
                            text: statusTitle(for: grant),
                            systemImage: grant.isActive ? "checkmark.shield" : "clock",
                            tint: grant.isActive ? Theme.primary : Theme.secondaryInk,
                            fill: grant.isActive ? Theme.sageSoft : Theme.surfaceSunken
                        )
                    }

                    if grant.isActive {
                        Button("Revoke access", role: .destructive) { revoking = grant }
                            .font(Theme.sans(13, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)

                if grant.id != grants.last?.id {
                    Divider().overlay(Theme.hairline)
                }
            }

            Text("Revoking records the change here. A file that was already handed over cannot be recalled.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    // MARK: Actions

    private func statusTitle(for grant: ShareGrant) -> String {
        if grant.isRevoked { return String(localized: "Revoked") }
        if grant.isExpired { return String(localized: "Expired") }
        return String(localized: "Active")
    }

    private func refreshCode() {
        guard let identity = try? DeviceKeyStore.existingIdentity() else {
            shareCode = nil
            return
        }
        shareCode = ShareCode.encode(identity)
    }

    private func createCode() {
        do {
            let identity = try DeviceKeyStore.identity()
            shareCode = ShareCode.encode(identity)
        } catch {
            show(error)
        }
    }

    private func removeCode() {
        DeviceKeyStore.deleteAll()
        shareCode = nil
        copied = false
    }

    private func revoke(_ grant: ShareGrant) {
        grant.revokedAt = Date()
        context.insert(ShareAccessLog(action: "Revoked", grant: grant))
        try? context.save()
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            do {
                pendingData = try Data(contentsOf: url)
                showingOpenSheet = true
            } catch {
                showError("The file could not be read.")
            }
        case .failure(let error):
            show(error)
        }
    }

    private func show(_ error: Error) {
        showError(error.localizedDescription)
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
