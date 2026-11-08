//
//  JurisdictionRule.swift
//  Grow Companion
//
//  The shape of one jurisdiction's home-cultivation rule set. The bundled data
//  uses the same shape a signed remote rule pack will use later, so updating
//  limits never requires an app release.
//

import Foundation

enum LimitScope: String, Codable, Hashable {
    case residence
    case person

    var title: String {
        switch self {
        case .residence: return "per residence"
        case .person: return "per adult"
        }
    }
}

struct JurisdictionRule: Identifiable, Hashable {
    let stateCode: String
    let stateName: String
    let cultivable: Bool
    let plantLimit: Int?
    let limitScope: LimitScope
    let countedStages: [PlantStage]
    let countsClones: Bool
    let countingNote: String
    let possessionLimitGrams: Double?
    let canopyLimitSqM: Double?
    let indoorAllowed: Bool
    let outdoorAllowed: Bool
    let medicalCardRequired: Bool
    let registrationRequired: Bool
    let registrationNote: String
    let summary: String
    let citation: String
    let sourceURL: String
    let verifiedOn: String
    let effectiveOn: String?
    let cityOverrideWarning: Bool

    var id: String { "US-\(stateCode)" }
    var jurisdictionCode: String { id }

    init(
        stateCode: String,
        stateName: String,
        cultivable: Bool = true,
        plantLimit: Int?,
        limitScope: LimitScope = .residence,
        countedStages: [PlantStage] = [.veg, .flower],
        countsClones: Bool = false,
        countingNote: String = "",
        possessionLimitGrams: Double? = nil,
        canopyLimitSqM: Double? = nil,
        indoorAllowed: Bool = true,
        outdoorAllowed: Bool = true,
        medicalCardRequired: Bool = false,
        registrationRequired: Bool = false,
        registrationNote: String = "",
        summary: String,
        citation: String,
        sourceURL: String,
        verifiedOn: String = RulePack.verifiedOn,
        effectiveOn: String? = nil,
        cityOverrideWarning: Bool = true
    ) {
        self.stateCode = stateCode
        self.stateName = stateName
        self.cultivable = cultivable
        self.plantLimit = plantLimit
        self.limitScope = limitScope
        self.countedStages = countedStages
        self.countsClones = countsClones
        self.countingNote = countingNote
        self.possessionLimitGrams = possessionLimitGrams
        self.canopyLimitSqM = canopyLimitSqM
        self.indoorAllowed = indoorAllowed
        self.outdoorAllowed = outdoorAllowed
        self.medicalCardRequired = medicalCardRequired
        self.registrationRequired = registrationRequired
        self.registrationNote = registrationNote
        self.summary = summary
        self.citation = citation
        self.sourceURL = sourceURL
        self.verifiedOn = verifiedOn
        self.effectiveOn = effectiveOn
        self.cityOverrideWarning = cityOverrideWarning
    }

    /// Plain-language label for the indoor/outdoor rule.
    var placementLabel: String {
        switch (indoorAllowed, outdoorAllowed) {
        case (true, true): return "Indoor and outdoor"
        case (true, false): return "Indoor only"
        case (false, true): return "Outdoor only"
        case (false, false): return "Not allowed"
        }
    }

    var plantLimitLabel: String {
        guard cultivable, let limit = plantLimit else { return "Not permitted" }
        return "\(limit) plants \(limitScope.title)"
    }

    var recountNeeded: Bool {
        RulePack.isStale(self)
    }
}
