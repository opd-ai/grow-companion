//
//  BreederLibrary.swift
//  Grow Companion
//
//  The breeder reference the strain screens use: bundled profiles keyed by a
//  normalised breeder name, the grower's own notes attached beside them, the
//  lineage claimed for a bundled cultivar, and the comparison between a
//  cultivar's claimed flowering window and the grower's own finished cycles.
//

import Foundation

enum BreederLibrary {
    /// Bundled reference material, reviewed with the rule pack. A future signed
    /// content pack can carry the same shape; nothing here fetches it.
    static let reviewedOn = date(year: 2025, month: 5, day: 15)

    static let sourceLine = String(localized: "Bundled reference profile")

    /// The comparison caveat shown wherever a claim sits beside a result.
    static let claimCaveat = String(localized: "Breeder figures are claims from reference material, not verified results. Your own cycles are counted from your records and are never blended with the claim.")

    /// Lineage caveat. Parents are disputed for many modern cultivars, so the
    /// app says so rather than presenting a single family tree as fact.
    static let lineageCaveat = String(localized: "Lineages are often disputed. Treat a parent line as a claim, not a fact.")

    // MARK: Normalisation

    /// Case-, accent-, punctuation- and spacing-insensitive key. Two strains
    /// that spell the same breeder differently still point at one profile.
    static func key(for name: String) -> String {
        let folded = name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "&", with: " and ")
        let characters = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(characters)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    // MARK: Profiles

    static let profiles: [BreederProfile] = [
        profile(
            name: "Humboldt Seed Organization",
            summary: "Seed breeder behind several modern hybrid lines, including Blue Dream.",
            notes: "Catalogue listings usually give a flowering window per cultivar in weeks. The window is the breeder's own estimate for a mature plant in a suitable room; it is not a promise for every phenotype.",
            links: []
        ),
        profile(
            name: "Sensi Seeds",
            summary: "Long-running Amsterdam seed breeder with classic indica and sativa lines.",
            notes: "One of the oldest names in the catalogue. Its listings carry per-cultivar flowering windows, and several of its classic lines are the reference point other breeders describe their plants against.",
            links: ["https://sensiseeds.com"]
        ),
        profile(
            name: "Green House Seeds",
            summary: "Seed breeder with an established catalogue of hybrid lines, including White Widow.",
            notes: "Cultivar descriptions list an indoor flowering window and a suggested plant height. Both are the breeder's own figures from its catalogue rather than measured results.",
            links: []
        ),
        profile(
            name: "GG Strains",
            summary: "Breeder credit behind GG4, the Gorilla Glue #4 cut.",
            notes: "The credit for GG4 and the lineage behind the cut are widely disputed between the people involved. Packs and cuts are sold under the GG Strains name; the app repeats that as a claim only.",
            links: []
        ),
        profile(
            name: "Reservoir Seeds",
            summary: "Small seed breeder associated with Sour Diesel lines.",
            notes: "Its catalogue is small and its descriptions are brief. The flowering window is the breeder's estimate, and the lineage behind Sour Diesel is described differently by different breeders.",
            links: []
        ),
        profile(
            name: "Ken Estes",
            summary: "Breeder credited with Granddaddy Purple.",
            notes: "Granddaddy Purple is sold under several labels, and the breeder credit is part of the marketing rather than a verified record. Treat the claim as a name attached to the cultivar.",
            links: []
        ),
        profile(
            name: "DNA Genetics",
            summary: "Amsterdam seed breeder with a broad hybrid catalogue, including OG Kush.",
            notes: "Its catalogue gives a flowering window per cultivar. Several of its best-known lines are sold as cuts as well as seeds, and the two are not the same plant.",
            links: []
        ),
        profile(
            name: "DJ Short",
            summary: "Breeder credited with Blueberry and several classic indica lines.",
            notes: "Its cultivars are described in prose rather than tables, and the flowering window is roughly given. The lineage stories in the catalogue are the breeder's own account.",
            links: []
        ),
        profile(
            name: "Royal Queen Seeds",
            summary: "Seed breeder with a broad catalogue, including Amnesia Haze.",
            notes: "Its listings give an indoor flowering window and a yield estimate in grams per plant. Both are the breeder's figures for a well-run room and vary with phenotype and method.",
            links: ["https://www.royalqueenseeds.com"]
        ),
        profile(
            name: "Sherbinski",
            summary: "Breeder credited with the Gelato lines.",
            notes: "Gelato is sold as numbered cuts and as seeds under several labels. The breeder credit and the numbering are claims; the app repeats them without treating them as verified.",
            links: []
        ),
        profile(
            name: "Seed Junky Genetics",
            summary: "Breeder credited with Wedding Cake.",
            notes: "The catalogue gives flowering windows and other marketing figures. The app records the flowering window as a claim and does not repeat any figure about what a harvest may contain.",
            links: []
        )
    ]

    static func profile(named name: String, stored: [GrowerBreeder] = []) -> BreederProfile? {
        let lookup = key(for: name)
        guard !lookup.isEmpty else { return nil }
        return allProfiles(stored: stored).first { key(for: $0.name) == lookup }
    }

    static func profile(for strain: Strain) -> BreederProfile? {
        profile(named: strain.displayBreeder)
    }

    static func profiles(matching query: String, stored: [GrowerBreeder] = []) -> [BreederProfile] {
        let all = allProfiles(stored: stored)
        let lookup = key(for: query)
        guard !lookup.isEmpty else { return all }
        return all.filter {
            key(for: $0.name).contains(lookup)
                || key(for: $0.summary).contains(lookup)
                || key(for: $0.notes).contains(lookup)
                || key(for: $0.yourNotes ?? "").contains(lookup)
        }
    }

    // MARK: Lineage

    /// Lineage is claimed per cultivar, not per breeder: two cultivars from one
    /// breeder rarely share parents. Only the bundled templates with a
    /// documented or disputed claim appear here.
    static let lineages: [CultivarLineage] = [
        CultivarLineage(
            cultivar: "Blue Dream",
            breeder: "Humboldt Seed Organization",
            parentLines: "Blueberry × Haze",
            claimedYield: String(localized: "High indoor yield"),
            lineageStatus: .documented,
            source: String(localized: "Breeder pack description")
        ),
        CultivarLineage(
            cultivar: "Jack Herer",
            breeder: "Sensi Seeds",
            parentLines: "Haze × Northern Lights #5 × Shiva Skunk",
            claimedYield: String(localized: "Moderate to high"),
            lineageStatus: .disputed,
            source: String(localized: "Breeder catalogue")
        ),
        CultivarLineage(
            cultivar: "White Widow",
            breeder: "Green House Seeds",
            parentLines: "Brazilian sativa × South Indian indica",
            claimedYield: String(localized: "High indoor yield"),
            lineageStatus: .documented,
            source: String(localized: "Breeder catalogue")
        )
    ]

    /// The lineage claim for a cultivar, only when both the cultivar and the
    /// breeder match the bundled reference.
    static func lineage(forCultivar cultivar: String, breeder: String) -> CultivarLineage? {
        let cultivarKey = key(for: cultivar)
        let breederKey = key(for: breeder)
        guard !cultivarKey.isEmpty, !breederKey.isEmpty else { return nil }
        return lineages.first {
            key(for: $0.cultivar) == cultivarKey && key(for: $0.breeder) == breederKey
        }
    }

    static func lineage(for strain: Strain) -> CultivarLineage? {
        lineage(forCultivar: strain.name, breeder: strain.breeder)
    }

    // MARK: Strains and comparison

    static func strains(forBreeder name: String, in strains: [Strain]) -> [Strain] {
        let lookup = key(for: name)
        guard !lookup.isEmpty else { return [] }
        return strains
            .filter { key(for: $0.breeder) == lookup }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// The claimed figure and the grower's own observed average, side by side
    /// and never combined.
    static func summary(for strain: Strain) -> BreederCultivarSummary {
        let observed = StrainInsights.observedAverage(for: strain)
        return BreederCultivarSummary(
            name: strain.displayName,
            typeTitle: strain.type.title,
            claimedWeeks: max(1, strain.expectedFloweringWeeks),
            observedDays: observed?.days,
            finishedCycles: observed?.count ?? 0
        )
    }

    // MARK: Data assembly

    private static func profile(
        name: String,
        summary: LocalizedStringResource,
        notes: LocalizedStringResource,
        links: [String]
    ) -> BreederProfile {
        BreederProfile(
            name: name,
            summary: String(localized: summary),
            notes: String(localized: notes),
            links: links.compactMap(link),
            source: sourceLine,
            reviewedOn: reviewedOn
        )
    }

    private static func link(_ address: String) -> BreederLink? {
        guard let url = URL(string: address), let scheme = url.scheme, scheme == "https" else {
            return nil
        }
        return BreederLink(title: title(for: address), url: url)
    }

    private static func title(for url: String) -> String {
        guard let host = URL(string: url)?.host() else { return String(localized: "Website") }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Every bundled breeder's strains, for the index screen.
    static func strainCount(for profile: BreederProfile, in strains: [Strain]) -> Int {
        Self.strains(forBreeder: profile.name, in: strains).count
    }

    // MARK: The grower's own notes

    /// The source line for notes the grower wrote themselves.
    static let yourNotesSource = String(localized: "Your notes")

    /// One-line description for a breeder the bundled reference does not carry.
    static let growerOnlySummary = String(localized: "Added by you")

    /// The bundled profiles with the grower's notes attached, followed by the
    /// breeders only the grower has. A bundled breeder keeps its canonical name,
    /// so the reference, the strains and the profile stay matched by one key.
    static func allProfiles(stored: [GrowerBreeder] = []) -> [BreederProfile] {
        guard !stored.isEmpty else { return profiles }

        let byKey = Dictionary(
            stored.map { (key(for: $0.name), $0) },
            uniquingKeysWith: { first, second in
                first.updatedAt >= second.updatedAt ? first : second
            }
        )

        var merged: [BreederProfile] = profiles.map { profile in
            guard let record = byKey[key(for: profile.name)], !record.isEmpty else {
                return profile
            }
            let existing = Set(profile.links.map { $0.url.absoluteString.lowercased() })
            let added = websiteLinks(record).filter {
                !existing.contains($0.url.absoluteString.lowercased())
            }
            return BreederProfile(
                name: profile.name,
                summary: profile.summary,
                notes: profile.notes,
                links: profile.links + added,
                source: profile.source,
                reviewedOn: profile.reviewedOn,
                yourNotes: record.trimmedNotes.isEmpty ? nil : record.trimmedNotes,
                yourNotesUpdatedOn: record.updatedAt
            )
        }

        let bundledKeys = Set(profiles.map { key(for: $0.name) })
        let extra = byKey
            .filter { !bundledKeys.contains($0.key) && !$0.value.isEmpty }
            .values
            .map { record in
                BreederProfile(
                    name: record.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    summary: growerOnlySummary,
                    notes: "",
                    links: websiteLinks(record),
                    source: yourNotesSource,
                    reviewedOn: record.updatedAt,
                    yourNotes: record.trimmedNotes.isEmpty ? nil : record.trimmedNotes,
                    yourNotesUpdatedOn: record.updatedAt,
                    isGrowerOnly: true
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        merged.append(contentsOf: extra)
        return merged
    }

    private static func websiteLinks(_ record: GrowerBreeder) -> [BreederLink] {
        guard let address = record.trimmedWebsite, let link = link(address) else { return [] }
        return [link]
    }

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 1_747_267_200)
    }
}
