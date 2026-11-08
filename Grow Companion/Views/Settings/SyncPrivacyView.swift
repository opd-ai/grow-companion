//
//  SyncPrivacyView.swift
//  Grow Companion
//
//  Honest, read-only explanation of what leaves this device, plus the local
//  device key that the protected-envelope work uses. The app has no account,
//  server or sync engine, so this screen must never imply one exists.
//

import SwiftUI

struct SyncPrivacyView: View {
    private struct DeviceKeySummary {
        let createdAt: Date?
        let agreementID: String
        let signingID: String
    }

    @State private var keySummary: DeviceKeySummary?
    @State private var keyError: String?
    @State private var showRemoveKeys = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusCard
                encryptionCard
                leavesCard
                notAvailableCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { refreshKeys() }
        .confirmationDialog(
            "Remove the device key?",
            isPresented: $showRemoveKeys,
            titleVisibility: .visible
        ) {
            Button("Remove device key", role: .destructive) { removeKeys() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The key is only used by the protected-envelope code in this build. Removing it changes nothing you have recorded, and nothing has been sent anywhere.")
        }
        .alert("Device key", isPresented: Binding(
            get: { keyError != nil },
            set: { if !$0 { keyError = nil } }
        )) {
            Button("OK", role: .cancel) { keyError = nil }
        } message: {
            Text(keyError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sync and privacy")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("There is no cloud sync to protect, because there is no cloud sync in this version.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "iphone")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.onHero)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Theme.onHero.opacity(0.12)))

            VStack(alignment: .leading, spacing: 5) {
                Text("This device only")
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.onHero)
                Text("Grow Companion has no account, no server and no sync. Your records live in a protected store on this device, and every screen works offline.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.onHero.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard(fill: Theme.primary, padding: 18)
    }

    private var encryptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Device key", subtitle: "Prepared on this device, not in use")

            Text("Grow Companion can hold a device key pair for the protected envelopes that future sharing and sync would use. The key is stored in this device's Keychain, available only while it is unlocked, and never leaves it.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("It is not used to send anything today: there is no account, no server and no recipient.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if let keySummary {
                Divider().overlay(Theme.hairline)
                InfoRow(
                    label: "Created",
                    value: keySummary.createdAt.map { Format.shortDate($0) } ?? "Not recorded"
                )
                InfoRow(label: "Agreement key", value: keySummary.agreementID)
                InfoRow(label: "Signing key", value: keySummary.signingID)

                SecondaryButton("Remove device key", systemImage: "trash") {
                    showRemoveKeys = true
                }
            } else {
                PrimaryButton("Create device key", systemImage: "key") {
                    createKey()
                }
                .accessibilityHint("Creates a key pair on this device only. Nothing is sent anywhere.")
            }
        }
        .growCard()
    }

    private var leavesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionHeader("What can leave this device", subtitle: "Only when you choose it")

            bullet("An export or backup you save to Files. Where that copy goes afterwards is outside the app.")
            bullet("A device or iCloud backup made by iOS. Grow Companion does not control those copies, so delete-all cannot remove them.")
            bullet("The optional state lookup: one request handled by Apple's location service. The app keeps only a state or locality name.")
            bullet("Diagnostics you choose to send to support, after a preview you can redact.")

            Text("No analytics, crash reporting, advertising or third-party SDK is included, and nothing is uploaded in the background.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .growCard()
    }

    private var notAvailableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Not in this version")
            bullet("Cloud sync, encrypted or otherwise")
            bullet("Accounts, sign-in or device pairing")
            bullet("Conflict resolution between devices")
            bullet("Sharing records with another person")

            Text("If any of this is added, it will be an explicit opt-in and this screen will describe it before the feature ships.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14, radius: 16)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.primary).frame(width: 5, height: 5).padding(.top, 6)
            Text(text)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refreshKeys() {
        guard let identity = try? DeviceKeyStore.existingIdentity() else {
            keySummary = nil
            return
        }
        keySummary = summary(for: identity)
    }

    private func createKey() {
        do {
            let identity = try DeviceKeyStore.identity()
            keySummary = summary(for: identity)
        } catch {
            keyError = error.localizedDescription
        }
    }

    private func removeKeys() {
        DeviceKeyStore.deleteAll()
        keySummary = nil
    }

    private func summary(for identity: SecureEnvelope.Identity) -> DeviceKeySummary {
        DeviceKeySummary(
            createdAt: DeviceKeyStore.createdAt(),
            agreementID: SecureEnvelope.keyIDText(SecureEnvelope.keyID(for: identity.agreementPublicKey)),
            signingID: SecureEnvelope.keyIDText(SecureEnvelope.keyID(for: identity.signingPublicKey))
        )
    }
}
