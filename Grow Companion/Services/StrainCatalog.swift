//
//  StrainCatalog.swift
//  Grow Companion
//
//  The bundled cultivar templates. Flowering figures are the breeders' own
//  windows rounded to whole weeks; everything stays editable after adding.
//

import Foundation

struct StrainTemplate: Identifiable, Hashable {
    let name: String
    let breeder: String
    let type: StrainType
    let expectedFloweringWeeks: Int
    let notes: String

    var id: String { name }
}

enum StrainCatalog {
    static let templates: [StrainTemplate] = [
        StrainTemplate(
            name: "Blue Dream",
            breeder: "Humboldt Seed Organization",
            type: .hybrid,
            expectedFloweringWeeks: 9,
            notes: "Sativa-leaning hybrid that stretches through the first weeks of flower. Train early to keep the canopy even."
        ),
        StrainTemplate(
            name: "Northern Lights",
            breeder: "Sensi Seeds",
            type: .indica,
            expectedFloweringWeeks: 7,
            notes: "Compact and forgiving, and it finishes quickly. A sensible first photoperiod indoors."
        ),
        StrainTemplate(
            name: "White Widow",
            breeder: "Green House Seeds",
            type: .hybrid,
            expectedFloweringWeeks: 8,
            notes: "Heavy resin from mid-flower. Watch humidity once the buds thicken."
        ),
        StrainTemplate(
            name: "GG4",
            breeder: "GG Strains",
            type: .hybrid,
            expectedFloweringWeeks: 9,
            notes: "Vigorous and hungry in flower. Support the branches once the buds put on weight."
        ),
        StrainTemplate(
            name: "Sour Diesel",
            breeder: "Reservoir Seeds",
            type: .sativa,
            expectedFloweringWeeks: 10,
            notes: "Tall sativa that needs headroom. Expect a long stretch before flowers set."
        ),
        StrainTemplate(
            name: "Granddaddy Purple",
            breeder: "Ken Estes",
            type: .indica,
            expectedFloweringWeeks: 8,
            notes: "Broad leaves and dense buds. Cooler nights late in flower bring out the colour."
        ),
        StrainTemplate(
            name: "Jack Herer",
            breeder: "Sensi Seeds",
            type: .sativa,
            expectedFloweringWeeks: 9,
            notes: "Branching sativa with an even canopy. Keep the dark period completely dark."
        ),
        StrainTemplate(
            name: "OG Kush",
            breeder: "DNA Genetics",
            type: .hybrid,
            expectedFloweringWeeks: 8,
            notes: "Stretchy early in flower with a modest yield. Watch calcium and magnesium."
        ),
        StrainTemplate(
            name: "Blueberry",
            breeder: "DJ Short",
            type: .indica,
            expectedFloweringWeeks: 8,
            notes: "Short, bushy plants. Some phenotypes colour up quickly in cool conditions."
        ),
        StrainTemplate(
            name: "Amnesia Haze",
            breeder: "Royal Queen Seeds",
            type: .sativa,
            expectedFloweringWeeks: 11,
            notes: "Long flowering sativa. Plan for the extra weeks and keep airflow strong."
        ),
        StrainTemplate(
            name: "Gelato 41",
            breeder: "Sherbinski",
            type: .hybrid,
            expectedFloweringWeeks: 9,
            notes: "Dense, resinous buds that hold moisture. Keep the drying space in its range."
        ),
        StrainTemplate(
            name: "Wedding Cake",
            breeder: "Seed Junky Genetics",
            type: .hybrid,
            expectedFloweringWeeks: 9,
            notes: "Compact hybrid with heavy frost. Lighter feeds go further than heavy ones."
        )
    ]

    static func referenceContext(for breeder: String) -> StrainReferenceContext {
        let normalized = breeder.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "humboldt seed organization":
            return StrainReferenceContext(
                breederProfile: BreederProfileReference(name: "Humboldt Seed Organization", summary: "A California seed company known for modern hybrid lines and pack-level flowering estimates.", source: "Bundled reference profile"),
                parentLines: "Blueberry × Haze",
                claimedYield: "High indoor yield",
                source: "Breeder pack description"
            )
        case "sensi seeds":
            return StrainReferenceContext(
                breederProfile: BreederProfileReference(name: "Sensi Seeds", summary: "A long-running seed breeder with classic lines and published cultivar descriptions.", source: "Bundled reference profile"),
                parentLines: "Afghan landrace selection × Northern Lights #5",
                claimedYield: "Moderate to high",
                source: "Breeder catalog"
            )
        case "green house seeds":
            return StrainReferenceContext(
                breederProfile: BreederProfileReference(name: "Green House Seeds", summary: "A seed breeder and reference source for several established hybrid lines.", source: "Bundled reference profile"),
                parentLines: "Brazilian sativa × South Indian indica",
                claimedYield: "High indoor yield",
                source: "Breeder catalog"
            )
        default:
            return StrainReferenceContext(breederProfile: nil, parentLines: nil, claimedYield: nil, source: nil)
        }
    }
}
