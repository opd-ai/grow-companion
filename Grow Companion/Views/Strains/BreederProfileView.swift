//
//  BreederProfileView.swift
//  Grow Companion
//
//  One bundled breeder: the reference profile, the strains in the grower's
//  library that point at it, and the claimed figures held apart from results.
//

import SwiftUI
import SwiftData

struct BreederProfileView: View {
    let profile: BreederProfile

    @Query(sort: \Strain.name) private var strains: [Strain]

    private var breederStrains: [Strain] {
        BreederLibrary.strains(forBreeder: profile.name, in: strains)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                strainsCard
                caveatCard
                if profile.hasLinks { linksCard }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.ink)
                Text(profile.summary)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(profile.notes)
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Theme.hairline)

            InfoRow(label: String(localized: "Source"), value: profile.source)
            InfoRow(label: String(localized: "Reviewed"), value: Format.shortDate(profile.reviewedOn))
        }
        .growCard()
        .accessibilityElement(children: .contain)
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

    private var linksCard: some View {
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
}
