//
//  SyncPrivacyView.swift
//  Grow Companion
//
//  Honest, read-only explanation of what leaves this device. The app has no
//  account, server or sync engine, so this screen must never imply one exists.
//

import SwiftUI

struct SyncPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusCard
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
}
