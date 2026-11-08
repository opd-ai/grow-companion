//
//  BreederLibraryTests.swift
//  Grow CompanionTests
//
//  The bundled breeder reference: how names are matched, which cultivars carry
//  a lineage claim, how a claim sits beside the grower's own finished cycles,
//  and the copy limits the roadmap sets for reference material.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct BreederLibraryTests {
    // MARK: Matching

    @Test func namesMatchIgnoringCaseAccentsAndPunctuation() {
        let key = { BreederLibrary.key(for: $0) }

        #expect(key("  Sensi Seeds ") == "sensi seeds")
        #expect(key("SÉNSI SEEDS") == "sensi seeds")
        #expect(key("Sensi-Seeds") == "sensi seeds")
        #expect(key("GG Strains & Co") == "gg strains and co")
        #expect(key("") == "")
        #expect(key("   ") == "")
    }

    @Test func aProfileIsFoundByAnySpellingOfItsName() throws {
        let profile = try #require(BreederLibrary.profile(named: "  sensi   seeds "))

        #expect(profile.name == "Sensi Seeds")
        #expect(BreederLibrary.profile(named: "Sensi Seeds") == profile)
    }

    @Test func anUnknownOrEmptyBreederHasNoProfile() {
        #expect(BreederLibrary.profile(named: "No Such Breeder") == nil)
        #expect(BreederLibrary.profile(named: "") == nil)
        #expect(BreederLibrary.profile(named: "   ") == nil)
    }

    @Test func theProfileListCoversEveryBundledTemplateBreeder() {
        let templateKeys = Set(StrainCatalog.templates.map { BreederLibrary.key(for: $0.breeder) })
        let profileKeys = Set(BreederLibrary.profiles.map { BreederLibrary.key(for: $0.name) })

        #expect(profileKeys == templateKeys)
    }

    @Test func profilesAreUniqueAndComplete() {
        let keys = BreederLibrary.profiles.map { BreederLibrary.key(for: $0.name) }
        #expect(Set(keys).count == keys.count)

        for profile in BreederLibrary.profiles {
            #expect(!profile.summary.isEmpty, "\(profile.name) has no summary")
            #expect(!profile.notes.isEmpty, "\(profile.name) has no notes")
            #expect(!profile.source.isEmpty)
            #expect(profile.reviewedOn == BreederLibrary.reviewedOn)
        }
    }

    @Test func bundledLinksAreHttpsAndTitled() {
        for profile in BreederLibrary.profiles {
            for link in profile.links {
                #expect(link.url.scheme == "https", "\(profile.name) has a non-https link")
                #expect(!link.title.isEmpty)
            }
        }
    }

    @Test func searchMatchesNameAndCopy() {
        #expect(BreederLibrary.profiles(matching: "sensi").contains { $0.name == "Sensi Seeds" })
        #expect(BreederLibrary.profiles(matching: "blue dream").contains { $0.name == "Humboldt Seed Organization" })
        #expect(BreederLibrary.profiles(matching: "no such breeder").isEmpty)

        #expect(BreederLibrary.profiles(matching: "  ").count == BreederLibrary.profiles.count)
    }

    // MARK: Lineage

    @Test func lineageBelongsToACultivarNotToItsBreeder() throws {
        let blueDream = try #require(
            BreederLibrary.lineage(forCultivar: "  blue dream ", breeder: "Humboldt Seed Organization")
        )

        #expect(blueDream.parentLines == "Blueberry × Haze")
        #expect(blueDream.lineageStatus == .documented)
        #expect(blueDream.claimedYield != nil)

        // The same breeder's other cultivars have no bundled claim.
        #expect(BreederLibrary.lineage(forCultivar: "Sour Diesel", breeder: "Humboldt Seed Organization") == nil)
        // The same cultivar under another breeder does not inherit Humboldt's claim.
        #expect(BreederLibrary.lineage(forCultivar: "Blue Dream", breeder: "Sensi Seeds") == nil)
    }

    @Test func aDisputedLineageSaysSo() throws {
        let jackHerer = try #require(
            BreederLibrary.lineage(forCultivar: "Jack Herer", breeder: "Sensi Seeds")
        )

        #expect(jackHerer.lineageStatus == .disputed)
        #expect(!jackHerer.parentLines.isEmpty)
    }

    @Test func everyLineageReferencesABundledTemplate() {
        for lineage in BreederLibrary.lineages {
            let matches = StrainCatalog.templates.contains {
                $0.name == lineage.cultivar && $0.breeder == lineage.breeder
            }
            #expect(matches, "\(lineage.cultivar) is not a bundled template")
            #expect(!lineage.parentLines.isEmpty)
            #expect(!lineage.source.isEmpty)
        }
    }

    @Test func anEmptyCultivarOrBreederHasNoLineage() {
        #expect(BreederLibrary.lineage(forCultivar: "", breeder: "Sensi Seeds") == nil)
        #expect(BreederLibrary.lineage(forCultivar: "Jack Herer", breeder: "") == nil)
    }

    // MARK: Strains

    @Test func strainMatchingUsesTheSameNormalisedKey() {
        let one = Strain(name: "One", breeder: "sensi seeds")
        let two = Strain(name: "Two", breeder: "  Sensi Seeds ")
        let three = Strain(name: "Three", breeder: "")

        let matches = BreederLibrary.strains(forBreeder: "SENSI SEEDS", in: [one, two, three])

        #expect(matches.count == 2)
        #expect(matches.map(\.name) == ["One", "Two"])

        let profile = BreederLibrary.profile(named: "Sensi Seeds")
        #expect(profile.map { BreederLibrary.strainCount(for: $0, in: [one, two, three]) } == 2)
        #expect(BreederLibrary.strains(forBreeder: "", in: [one, two]).isEmpty)
    }

    @Test func strainsAreSortedByName() {
        let a = Strain(name: "Zulu", breeder: "Sensi Seeds")
        let b = Strain(name: "Alpha", breeder: "Sensi Seeds")

        #expect(BreederLibrary.strains(forBreeder: "Sensi Seeds", in: [a, b]).map(\.name) == ["Alpha", "Zulu"])
    }

    // MARK: The claim beside the result

    @Test func aClaimWithoutAFinishedCycleShowsNothingToCompare() {
        let strain = Strain(name: "One", breeder: "Sensi Seeds", expectedFloweringWeeks: 8)

        let summary = BreederLibrary.summary(for: strain)

        #expect(summary.claimedWeeks == 8)
        #expect(summary.observedDays == nil)
        #expect(summary.finishedCycles == 0)
        #expect(summary.observedLabel == nil)
        #expect(summary.comparison == nil)
        #expect(summary.claimedLabel.contains("8"))
        #expect(summary.claimedLabel.lowercased().contains("claimed"))
    }

    @Test func theComparisonStatesHowTheGrowersCyclesRan() throws {
        let claimed = max(1, 8) * 7

        let matching = BreederCultivarSummary(
            name: "One", typeTitle: "Hybrid", claimedWeeks: 8,
            observedDays: Double(claimed), finishedCycles: 2
        )
        #expect(matching.comparison?.contains("matches") == true)
        #expect(matching.observedLabel?.contains("2") == true)

        let longer = BreederCultivarSummary(
            name: "One", typeTitle: "Hybrid", claimedWeeks: 8,
            observedDays: Double(claimed + 7), finishedCycles: 1
        )
        #expect(longer.comparison?.contains("longer") == true)
        #expect(longer.comparison?.contains("7") == true)

        let shorter = BreederCultivarSummary(
            name: "One", typeTitle: "Hybrid", claimedWeeks: 8,
            observedDays: Double(claimed - 3), finishedCycles: 1
        )
        #expect(shorter.comparison?.contains("shorter") == true)
        #expect(shorter.comparison?.contains("3") == true)
    }

    @Test func aZeroClaimIsReadAsOneWeek() {
        let summary = BreederCultivarSummary(
            name: "One", typeTitle: "Hybrid", claimedWeeks: 0,
            observedDays: 7, finishedCycles: 1
        )

        #expect(summary.claimedLabel.contains("0"))
        #expect(summary.comparison?.contains("matches") == true)
    }

    // MARK: Copy limits

    @Test func referenceMaterialAvoidsPotencyAndDiagnosisClaims() {
        let banned = ["thc", "potency", "cannabinoid", "lab test", "diagnos", "medical"]
        let caveat = BreederLibrary.claimCaveat.lowercased()

        for profile in BreederLibrary.profiles {
            let text = (profile.summary + " " + profile.notes).lowercased()
            for term in banned {
                #expect(!text.contains(term), "\(profile.name) mentions \(term)")
            }
        }

        for lineage in BreederLibrary.lineages {
            let text = (lineage.parentLines + " " + (lineage.claimedYield ?? "")).lowercased()
            for term in banned {
                #expect(!text.contains(term), "\(lineage.cultivar) mentions \(term)")
            }
        }

        #expect(caveat.contains("claims"))
        #expect(BreederLibrary.lineageCaveat.lowercased().contains("disputed"))
    }

    @Test func copyIsPresentForEveryUserFacingString() {
        #expect(!BreederLibrary.sourceLine.isEmpty)
        #expect(!BreederLibrary.claimCaveat.isEmpty)
        #expect(!BreederLibrary.lineageCaveat.isEmpty)
    }
}
