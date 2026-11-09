//
//  BreederLibraryView.swift
//  Grow Companion
//
//  The bundled breeder reference: who each breeder is, what the catalogue
//  claims, and which of the grower's strains point at it.
//

import SwiftUI
import SwiftData

struct BreederLibraryView: View {
    @Query(sort: \Strain.name) private var strains: [Strain]
    @Query(sort: \GrowerBreeder.name) private var storedBreeders: [GrowerBreeder]

    @State private var query = ""
    @State private var showingNewBreeder = false

    private var profiles: [BreederProfile] {
        BreederLibrary.profiles(matching: query, stored: storedBreeders)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                referenceNote

                if profiles.isEmpty {
                    emptyState
                } else {
                    profileList
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Breeders")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: Text("Search breeders"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewBreeder = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Add a breeder"))
            }
        }
        .sheet(isPresented: $showingNewBreeder) {
            BreederNoteEditor(name: "", existing: nil, isBundledBreeder: false)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Breeder reference")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text(String(localized: "Bundled profiles for the breeders in your library, reviewed \(Format.shortDate(BreederLibrary.reviewedOn)), and the notes you keep yourself."))
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var referenceNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text("Reference material kept separate from your results. Add your own notes to any breeder, or add one the bundle does not list. Nothing here is uploaded, and no live lookup is made.")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .growCard(fill: Theme.surfaceSunken, padding: 14)
        .accessibilityElement(children: .combine)
    }

    private var profileList: some View {
        VStack(spacing: 0) {
            ForEach(profiles) { profile in
                NavigationLink {
                    BreederProfileView(name: profile.name)
                } label: {
                    row(profile)
                }
                .buttonStyle(.plain)

                if profile.id != profiles.last?.id {
                    Divider().overlay(Theme.hairline)
                }
            }
        }
        .growCard(padding: 14)
    }

    private func row(_ profile: BreederProfile) -> some View {
        let count = BreederLibrary.strainCount(for: profile, in: strains)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sageSoft)
                    .frame(width: 40, height: 40)
                Image(systemName: profile.isGrowerOnly ? "person.crop.circle.badge.plus" : "person.crop.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if profile.isGrowerOnly {
                        Pill(
                            text: String(localized: "Yours"),
                            systemImage: "person.fill",
                            tint: Theme.primary,
                            fill: Theme.sageSoft
                        )
                    } else if profile.hasYourNotes {
                        Image(systemName: "note.text")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .accessibilityLabel(String(localized: "You have notes for this breeder"))
                    }
                }
                Text(profile.summary)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Text(count == 0
                ? String(localized: "No strains")
                : String(localized: "\(count) strain\(count == 1 ? "" : "s")"))
                .font(Theme.sans(11, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text("No breeder matches")
                .font(Theme.sans(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Try the breeder's name as it appears on the pack. Profiles are matched by name, ignoring case, accents and punctuation.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .growCard()
    }
}
