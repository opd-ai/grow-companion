//
//  BreederProfileView.swift
//  Grow Companion
//
//  One breeder: the reference profile, the grower's own notes beside it, the
//  strains in the library that point at it, and the claimed figures held apart
//  from results. A breeder the bundle does not carry is shown the same way,
//  with the grower's notes as the only profile.
//

import SwiftUI
import SwiftData

struct BreederProfileView: View {
    let name: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Strain.name) private var strains: [Strain]
    @Query(sort: \GrowerBreeder.name) private var storedBreeders: [GrowerBreeder]

    @State private var showingEditor = false
    @State private var showingDelete = false
    @State private var errorMessage: String?

    private var profile: BreederProfile? {
        BreederLibrary.profile(named: name, stored: storedBreeders)
    }

    private var storedRecord: GrowerBreeder? {
        GrowerBreederService.current(named: profile?.name ?? name, in: storedBreeders)
    }

    private var breederStrains: [Strain] {
        guard let profile else { return [] }
        return BreederLibrary.strains(forBreeder: profile.name, in: strains)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let profile {
                    headerCard(profile)
                    yourNotesCard(profile)
                    strainsCard
                    caveatCard
                    if profile.hasLinks { linksCard(profile) }
                    if profile.isGrowerOnly { deleteCard }
                } else {
                    missingCard
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(profile?.name ?? name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) {
            BreederNoteEditor(
                name: profile?.name ?? name,
                existing: storedRecord,
                isBundledBreeder: profile?.isGrowerOnly == false
            )
        }
        .confirmationDialog(
            "Delete this breeder?",
            isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your notes for this breeder are removed. Strains that name it keep the name.")
        }
    }

    private func headerCard(_ profile: BreederProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.ink)
                if !profile.summary.isEmpty {
                    Text(profile.summary)
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !profile.notes.isEmpty {
                Text(profile.notes)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(Theme.hairline)

            InfoRow(label: String(localized: "Source"), value: profile.source)
            if profile.isGrowerOnly {
                InfoRow(
                    label: String(localized: "Updated"),
                    value: Format.shortDate(profile.yourNotesUpdatedOn ?? profile.reviewedOn)
                )
            } else {
                InfoRow(label: String(localized: "Reviewed"), value: Format.shortDate(profile.reviewedOn))
            }
        }
        .growCard()
        .accessibilityElement(children: .contain)
    }

    private func yourNotesCard(_ profile: BreederProfile) -> some View {
        let updated = profile.yourNotesUpdatedOn.map { Format.shortDate($0) }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                "Your notes",
                subtitle: updated.map { String(localized: "Saved \($0)") }
                    ?? String(localized: "Kept on this device")
            )

            if let notes = profile.yourNotes, !notes.isEmpty {
                Text(notes)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No notes yet. Add what you learned about this breeder — a claim to check, a contact, or how their plants behaved in your room.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                showingEditor = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: profile.hasYourNotes ? "pencil" : "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text(profile.hasYourNotes
                        ? String(localized: "Edit your notes")
                        : String(localized: "Add your notes"))
                        .font(Theme.sans(14, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Theme.primary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Your notes stay beside the reference, never inside it, and nothing is uploaded.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(padding: 16)
    }

    private var strainsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                "Strains in your library",
                subtitle: breederStrains.isEmpty
                    ? String(localized: "Nothing uses this breeder yet")
                    : String(localized: "\(breederStrains.count) strain\(breederStrains.count == 1 ? "" : "s") point here")
            )

            if breederStrains.isEmpty {
                Text("Add a strain and type this breeder's name, or pick it from the suggestions in the editor. Profiles are matched by name, ignoring case, accents and punctuation.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(breederStrains) { strain in
                        NavigationLink {
                            StrainDetailView(strain: strain)
                        } label: {
                            strainRow(strain)
                        }
                        .buttonStyle(.plain)

                        if strain.id != breederStrains.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
            }
        }
        .growCard(padding: 16)
    }

    private func strainRow(_ strain: Strain) -> some View {
        let summary = BreederLibrary.summary(for: strain)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(summary.name)
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Pill(
                        text: String(localized: "Claimed"),
                        systemImage: "tag",
                        tint: Theme.amber,
                        fill: Theme.amberSoft
                    )
                }

                Text(summary.claimedLabel)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)

                if let observed = summary.observedLabel {
                    Text(observed)
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }

                if let comparison = summary.comparison {
                    Text(comparison)
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No finished cycle yet, so there is nothing of yours to compare.")
                        .font(Theme.sans(11))
                        .foregroundStyle(Theme.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
                .padding(.top, 3)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var caveatCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(BreederLibrary.claimCaveat)
                .font(Theme.sans(11))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(BreederLibrary.lineageCaveat)
                .font(Theme.sans(11))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .growCard(fill: Theme.amberSoft, padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func linksCard(_ profile: BreederProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Links", subtitle: "Opens in your browser")

            ForEach(profile.links) { link in
                Link(destination: link.url) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.title)
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(link.url.absoluteString)
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.tertiaryInk)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryInk)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Open \(link.title) at \(link.url.absoluteString)"))
            }

            Text("Nothing is uploaded. A link opens in your browser, outside the app.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard(padding: 16)
    }

    private var deleteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This breeder was added by you, not by the bundled reference.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                showingDelete = true
            } label: {
                Label("Delete this breeder", systemImage: "trash")
                    .font(Theme.sans(14, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .growCard(padding: 16)
    }

    private var missingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This breeder is no longer in your library")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Its notes were removed. Strains that name it keep the name, and you can add notes again from the breeder library.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }

    private func delete() {
        guard let record = storedRecord else { return }
        do {
            try GrowerBreederService.delete(record, in: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
