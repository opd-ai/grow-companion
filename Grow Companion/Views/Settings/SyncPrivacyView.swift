//
//  SyncPrivacyView.swift
//  Grow Companion
//
//  The privacy statement: everything is on this device, by design. There is no
//  account, server, sync or network request, so there is nothing to sign into
//  and nothing to send. The share key is the one key this app holds, and it is
//  used only by the share file the grower writes themselves.
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
                leavesCard
                keyCard
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
            "Remove the share key?",
            isPresented: $showRemoveKeys,
            titleVisibility: .visible
        ) {
            Button("Remove share key", role: .destructive) { removeKeys() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The key is only used to protect share files you create yourself. Removing it changes nothing you have recorded, and nothing has been sent anywhere.")
        }
        .alert("Share key", isPresented: Binding(
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
            Text("Privacy")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("This app is on-device only, by design. There is nothing to sign into, nothing to sync and no request for data to leave the phone.")
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
                Text("No account, no server, no sync and no network request. Your records live in a protected store on this device and every screen works offline.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.onHero.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .growCard(fill: Theme.primary, padding: 18)
    }

    private var leavesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionHeader("What can leave this device", subtitle: "Only when you choose it")

            bullet("An export or backup you save to Files. Where that copy goes afterwards is outside the app.")
            bullet("A share file you create and send yourself. Its recipient holds a read-only copy.")
            bullet("A device or iCloud backup made by iOS. Grow Companion does not control those copies, so delete-all cannot remove them.")

            Text("The app itself opens no network connection. No analytics, crash reporting, advertising or third-party SDK is included, and nothing is uploaded in the background.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .growCard()
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Share key", subtitle: "On this device, for your own share files")

            Text("Grow Companion holds one device key pair. It signs and encrypts the share files you create yourself, so a recipient can tell the file came from this device and read only what you chose to include.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("The key is stored in this device's Keychain, available only while it is unlocked, and never leaves it. It is not used to send anything on its own.")
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

                SecondaryButton("Remove share key", systemImage: "trash") {
                    showRemoveKeys = true
                }
            } else {
                PrimaryButton("Create share key", systemImage: "key") {
                    createKey()
                }
                .accessibilityHint("Creates a key pair on this device only. Nothing is sent anywhere.")
            }
        }
        .growCard()
    }

    private var notAvailableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Not part of this app")
            bullet("Cloud sync, encrypted or otherwise")
            bullet("Accounts, sign-in or device pairing")
            bullet("Community posts, groups or a public profile")
            bullet("Remote rule or content downloads")

            Text("These are not waiting on a review or a future release. A private record that never leaves the device is the product, so there is no network layer to turn on later.")
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
