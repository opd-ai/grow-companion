//
//  BreederProfile.swift
//  Grow Companion
//
//  Read-only reference material for the breeders behind the bundled cultivars.
//  A profile is a value, not a record: the library ships with the app, the
//  grower's own results stay in the store, and the two are never blended.
//

import Foundation

/// A bundled link to a breeder's own site. Only added where the address is
/// known, because a wrong link is worse than none.
struct BreederLink: Hashable, Identifiable {
    let title: String
    let url: URL

    var id: String { url.absoluteString }
}

/// One breeder profile, bundled or partly the grower's own. The reference copy
/// and the grower's notes are separate fields on purpose: the app never blends
/// a claim with something the grower wrote.
struct BreederProfile: Hashable, Identifiable {
    let name: String
    let summary: String
    let notes: String
    let links: [BreederLink]
    let source: String
    let reviewedOn: Date

    /// The grower's own notes for this breeder, kept beside the reference.
    var yourNotes: String?
    /// When the grower last saved those notes.
    var yourNotesUpdatedOn: Date?
    /// True when the profile exists only because the grower added it.
    var isGrowerOnly: Bool = false

    var id: String { name }

    var hasLinks: Bool { !links.isEmpty }

    var hasYourNotes: Bool { !(yourNotes ?? "").isEmpty }
}

/// Reference lineage for one bundled cultivar. Kept per cultivar rather than
/// per breeder, because two cultivars from the same breeder rarely share
/// parents, and a lineage is a claim that is often disputed.
struct CultivarLineage: Hashable, Identifiable {
    let cultivar: String
    let breeder: String
    let parentLines: String
    let claimedYield: String?
    let lineageStatus: LineageStatus
    let source: String

    var id: String { cultivar + "|" + breeder }
}

/// What one cultivar's claims look like beside the grower's own finished
/// cycles, without merging the two figures.
struct BreederCultivarSummary: Hashable, Identifiable {
    let name: String
    let typeTitle: String
    let claimedWeeks: Int
    let observedDays: Double?
    let finishedCycles: Int

    var id: String { name + "|" + typeTitle }

    var claimedLabel: String {
        String(localized: "\(claimedWeeks) week\(claimedWeeks == 1 ? "" : "s") claimed")
    }

    var observedLabel: String? {
        guard let observedDays else { return nil }
        return String(localized: "Your \(StrainInsights.shortLengthText(days: observedDays)) over \(finishedCycles) cycle\(finishedCycles == 1 ? "" : "s")")
    }

    /// Compares the grower's average with the claim, in the claim's own unit.
    /// Nil until one of the grower's cycles has finished.
    var comparison: String? {
        guard let observedDays else { return nil }
        let claimedDays = max(1, claimedWeeks) * 7
        let difference = Int(observedDays.rounded()) - claimedDays
        if difference == 0 {
            return String(localized: "Your average matches the breeder's window.")
        }
        let amount = Format.dayCount(abs(difference))
        if difference > 0 {
            return String(localized: "Your cycles averaged \(amount) longer than the claim.")
        }
        return String(localized: "Your cycles averaged \(amount) shorter than the claim.")
    }
}
