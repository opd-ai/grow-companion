//
//  SharingView.swift
//  Grow Companion
//
//  Scoped, read-only share configuration and local access log.
//

import SwiftUI
import SwiftData

struct SharingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShareGrant.createdAt, order: .reverse) private var grants: [ShareGrant]
    @Query(sort: \Room.createdAt) private var rooms: [Room]
    @Query(sort: \Plant.plantedAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \ShareAccessLog.date, order: .reverse) private var accessLogs: [ShareAccessLog]

    @State private var showingNewShare = false
    @State private var revoking: ShareGrant?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if grants.isEmpty {
                    emptyState
                } else {
                    activeShares
                    history
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewShare = true } label: { Image(systemName: "plus") }
                    .foregroundStyle(Theme.primary)
                    .accessibilityLabel("Create a read-only share")
            }
        }
        .sheet(isPresented: $showingNewShare) {
            NewShareView(rooms: rooms, plants: plants)
        }
        .confirmationDialog("Revoke this share?", isPresented: Binding(
            get: { revoking != nil },
            set: { if !$0 { revoking = nil } }
        ), titleVisibility: .visible) {
            Button("Revoke access", role: .destructive) {
                if let revoking { revoke(revoking) }
                revoking = nil
            }
            Button("Keep share", role: .cancel) { revoking = nil }
        } message: {
            Text("The recipient will no longer be authorized to use this read-only share. The access record stays on this device.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Read-only sharing")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text("Give a named consultant or peer a limited view of selected grow records.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Theme.primary)
            Text("No shared views")
                .font(Theme.serif(23))
                .foregroundStyle(Theme.ink)
            Text("Choose specific rooms or plants, then decide exactly which categories the recipient may see.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton("Create a read-only share", systemImage: "plus") { showingNewShare = true }
        }
        .growCard()
    }

    private var activeShares: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Shares", subtitle: "Active, expired and revoked views stay listed for your records")
            ForEach(grants) { grant in
                shareRow(grant)
            }
        }
    }

    private func shareRow(_ grant: ShareGrant) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(grant.recipientName)
                        .font(Theme.sans(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(grant.scopeSummary)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryInk)
                }
                Spacer()
                Pill(
                    text: grant.isRevoked ? "Revoked" : (grant.isExpired ? "Expired" : "Active"),
                    systemImage: grant.isActive ? "checkmark.shield" : "clock",
                    tint: grant.isActive ? Theme.primary : Theme.secondaryInk,
                    fill: grant.isActive ? Theme.sageSoft : Theme.surfaceSunken
                )
            }
            Text("Expires \(Format.shortDate(grant.expiresAt))")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
            if grant.isActive {
                Button("Revoke access", role: .destructive) { revoking = grant }
                    .font(Theme.sans(13, weight: .semibold))
            }
        }
        .growCard(padding: 15, radius: 20)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Access log", subtitle: "Creation and revocation events are stored locally")
            if accessLogs.isEmpty {
                Text("No access events yet.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                VStack(spacing: 0) {
                    ForEach(accessLogs.prefix(12)) { log in
                        HStack(spacing: 9) {
                            Image(systemName: log.action == "Revoked" ? "xmark.circle" : "clock.arrow.circlepath")
                                .foregroundStyle(log.action == "Revoked" ? Theme.amber : Theme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.action)
                                    .font(Theme.sans(13, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(Format.shortDate(log.date) + " · " + Format.time(log.date))
                                    .font(Theme.sans(11))
                                    .foregroundStyle(Theme.tertiaryInk)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 9)
                    }
                }
            }
        }
        .growCard(padding: 15)
    }

    private func revoke(_ grant: ShareGrant) {
        grant.revokedAt = Date()
        context.insert(ShareAccessLog(action: "Revoked", grant: grant))
        try? context.save()
    }
}

private struct NewShareView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let rooms: [Room]
    let plants: [Plant]
    @State private var recipientName = ""
    @State private var selectedRooms = Set<String>()
    @State private var selectedPlants = Set<String>()
    @State private var selectedCategories = Set(["Environment", "Plant records"])
    @State private var expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var showingReview = false

    private let categories = ["Environment", "Plant records", "Care history", "Harvest and cure", "Compliance"]

    private var canContinue: Bool {
        !recipientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!selectedRooms.isEmpty || !selectedPlants.isEmpty)
            && !selectedCategories.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Share a grow view")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("This creates a scoped, read-only access record. The personal journal and location are never available to share.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Recipient name")
                        TextField("Consultant or peer", text: $recipientName)
                            .textFieldStyle(.roundedBorder)
                    }

                    scopeSection
                    categorySection

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Access expires")
                        DatePicker("Up to 90 days", selection: $expiresAt, in: Date()...maxDate, displayedComponents: .date)
                            .tint(Theme.primary)
                    }
                    .growCard(fill: Theme.surfaceSunken, padding: 14, radius: 16)

                    PrimaryButton("Review access", systemImage: "person.badge.shield.checkmark", isEnabled: canContinue) {
                        showingReview = true
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.primary)
                }
            }
            .confirmationDialog("Review read-only access", isPresented: $showingReview, titleVisibility: .visible) {
                Button("Create share") { createShare() }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("\(recipientName) will see \(selectedRooms.count + selectedPlants.count) selected scope\(selectedRooms.count + selectedPlants.count == 1 ? "" : "s") and the categories you chose until \(Format.shortDate(expiresAt)). Recipients can copy or screenshot what they see.")
            }
        }
    }

    private var maxDate: Date {
        Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Choose scope", subtitle: "Select at least one room or plant")
            if rooms.isEmpty && plants.isEmpty {
                Text("Add a room or plant before creating a share.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.amber)
            }
            ForEach(rooms) { room in
                selectionRow(room.name, icon: "square.split.2x2", selected: selectedRooms.contains(room.name)) {
                    toggle(room.name, in: &selectedRooms)
                }
            }
            ForEach(plants) { plant in
                selectionRow(plant.displayName, icon: plant.stage.systemImage, selected: selectedPlants.contains(plant.displayName)) {
                    toggle(plant.displayName, in: &selectedPlants)
                }
            }
        }
        .growCard(padding: 14)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Allowed categories", subtitle: "Personal journal and location are excluded")
            ForEach(categories, id: \.self) { category in
                selectionRow(category, icon: "checkmark.shield", selected: selectedCategories.contains(category)) {
                    toggle(category, in: &selectedCategories)
                }
            }
            selectionRow("Personal journal", icon: "lock", selected: false, enabled: false) {}
            selectionRow("Location", icon: "lock", selected: false, enabled: false) {}
        }
        .growCard(padding: 14)
    }

    private func selectionRow(_ title: String, icon: String, selected: Bool, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(Theme.sans(13, weight: .semibold))
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .foregroundStyle(enabled ? (selected ? Theme.primary : Theme.secondaryInk) : Theme.tertiaryInk)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func createShare() {
        let grant = ShareGrant(
            recipientName: recipientName.trimmingCharacters(in: .whitespacesAndNewlines),
            roomNames: Array(selectedRooms).sorted(),
            plantNames: Array(selectedPlants).sorted(),
            categories: Array(selectedCategories).sorted(),
            expiresAt: expiresAt
        )
        context.insert(grant)
        context.insert(ShareAccessLog(action: "Created", grant: grant))
        try? context.save()
        dismiss()
    }
}
