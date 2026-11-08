//
//  SyncPrivacyView.swift
//  Grow Companion
//
//  Read-only status and privacy explanation for encrypted device sync.
//

import SwiftUI

struct SyncPrivacyView: View {
    @AppStorage("encryptedSyncEnabled") private var syncEnabled = false
    @AppStorage("encryptedSyncLastSuccess") private var lastSyncTimestamp: Double = 0
    @AppStorage("encryptedSyncPendingConflicts") private var pendingConflicts = 0

    private var lastSyncText: String {
        guard lastSyncTimestamp > 0 else { return "No successful sync recorded" }
        let date = Date(timeIntervalSince1970: lastSyncTimestamp)
        return "Last successful sync \(Format.shortDate(date)) at \(Format.time(date))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusCard
                protectedCard
                metadataCard
                offlineCard
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
            Text("Understand what is protected when your devices sync and what remains visible to the provider.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: syncEnabled ? "lock.icloud.fill" : "iphone")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(syncEnabled ? Theme.primary : Theme.secondaryInk)
                VStack(alignment: .leading, spacing: 4) {
                    Text(syncEnabled ? "Encrypted sync is on" : "Local-only state")
                        .font(Theme.sans(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(syncEnabled ? "Your records are protected before they leave this device." : "Encrypted device sync is not enabled. Your grow record remains available and protected on this device.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider().overlay(Theme.hairline)
            InfoRow(label: "Last successful sync", value: syncEnabled ? lastSyncText : "Not applicable")
            InfoRow(label: "Pending conflicts", value: syncEnabled ? "\(pendingConflicts)" : "0")
        }
        .growCard(fill: syncEnabled ? Theme.sageSoft : Theme.surfaceSunken)
    }

    private var protectedCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionHeader("Protected content", subtitle: "Encrypted before sync")
            bullet("Plant, room, journal and harvest record contents")
            bullet("Environment readings, care history and sensor-sourced values")
            bullet("Photos and notes included in the synced record")
            Text("The app keeps the decryption key on your approved devices. The provider cannot read the record contents from the encrypted payload.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionHeader("Visible metadata", subtitle: "Information needed to operate encrypted sync")
            bullet("Sync timing and whether a device is active")
            bullet("Encrypted record counts, sizes and change frequency")
            bullet("Device and account identifiers used to route sync data")
            bullet("Conflict and share relationships")
            Text("Metadata can reveal activity patterns even when record contents remain encrypted.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.amber)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.amberSoft))
        }
        .growCard()
    }

    private var offlineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Offline behavior")
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(Theme.primary)
                Text("The core grow record remains usable without connectivity. New records stay on this device until sync is available, and this screen never creates or changes grow data.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
