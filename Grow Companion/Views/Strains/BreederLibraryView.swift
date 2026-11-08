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

    @State private var query = ""

    private var profiles: [BreederProfile] {
        BreederLibrary.profiles(matching: query)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Breeder reference")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.ink)
            Text(String(localized: "Bundled profiles for the breeders in your library, reviewed \(Format.shortDate(BreederLibrary.reviewedOn))."))
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
            Text("Reference material kept separate from your results. Nothing here is uploaded, and no live lookup is made.")
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
                    BreederProfileView(profile: profile)
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
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
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
