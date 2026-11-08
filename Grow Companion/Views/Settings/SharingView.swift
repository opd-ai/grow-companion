//
//  SharingView.swift
//  Grow Companion
//
//  Sharing is not available in this version: there is no recipient identity,
//  no encrypted transport and no access model. This screen says so plainly and
//  lets the grower remove any local share notes left by earlier builds. It must
//  never present a local record as a working grant of access.
//

import SwiftUI
import SwiftData

struct SharingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShareGrant.createdAt, order: .reverse) private var grants: [ShareGrant]

    @State private var showRemoveConfirmation = false
    @State private var showRemoved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                unavailableCard
                if !grants.isEmpty {
                    localRecordsCard
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove the saved sharing records?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove local records", role: .destructive) {
                removeShareData()
            }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("These are local notes only. Removing them changes nothing on another person's device, because nothing was ever shared.")
        }
        .alert("Local records removed", isPresented: $showRemoved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The saved sharing notes have been removed from this device.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sharing")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Not available in this version.")
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.amber)
        }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Why sharing is not here", subtitle: "Nothing you record is sent to anyone")

            Text("Sharing a grow view would let another person see records about you and your home. That needs a recipient identity, a secure encrypted transport, clear expiry and revocation, and a legal and privacy review before it can ship.")
            .font(Theme.sans(13))
            .foregroundStyle(Theme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)

            Text("None of that exists today. Grow Companion has no server, no account and no way to send a record to a consultant or a peer.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("Personal notes, location and the cultivation journal are never shareable, and will stay excluded from any future sharing design.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private var localRecordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Saved local notes", subtitle: "From an earlier build — they grant no access")

            ForEach(grants) { grant in
                VStack(alignment: .leading, spacing: 4) {
                    Text(grant.recipientName.isEmpty ? "Unnamed entry" : grant.recipientName)
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Saved on this device only · nothing was shared")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)

                if grant.id != grants.last?.id {
                    Divider().overlay(Theme.hairline)
                }
            }

            SecondaryButton("Remove these local records", systemImage: "trash") {
                showRemoveConfirmation = true
            }
        }
        .growCard()
    }

    private func removeShareData() {
        _ = try? context.delete(model: ShareAccessLog.self)
        _ = try? context.delete(model: ShareGrant.self)
        try? context.save()
        showRemoved = true
    }
}
