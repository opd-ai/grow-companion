//
//  GrowProfile.swift
//  Grow Companion
//
//  The single on-device record of who the app is configured for: age
//  attestation, jurisdiction, residence type and experience level.
//

import Foundation
import SwiftData

@Model
final class GrowProfile {
    var ageConfirmed: Bool = false
    var ageAttestedAt: Date?
    var stateCode: String = ""
    var stateName: String = ""
    var countyOrCity: String = ""
    var residenceTypeRaw: String = ResidenceType.singleFamily.rawValue
    var landlordConsent: Bool = false
    var experienceLevelRaw: String = ExperienceLevel.beginner.rawValue
    var onboardingCompletedAt: Date?
    var jurisdictionConfirmedAt: Date?
    var educationOnly: Bool = false
    var createdAt: Date = Date()

    init(
        ageConfirmed: Bool = false,
        ageAttestedAt: Date? = nil,
        stateCode: String = "",
        stateName: String = "",
        countyOrCity: String = "",
        residenceType: ResidenceType = .singleFamily,
        landlordConsent: Bool = false,
        experienceLevel: ExperienceLevel = .beginner,
        onboardingCompletedAt: Date? = nil,
        jurisdictionConfirmedAt: Date? = nil,
        educationOnly: Bool = false,
        createdAt: Date = Date()
    ) {
        self.ageConfirmed = ageConfirmed
        self.ageAttestedAt = ageAttestedAt
        self.stateCode = stateCode
        self.stateName = stateName
        self.countyOrCity = countyOrCity
        self.residenceTypeRaw = residenceType.rawValue
        self.landlordConsent = landlordConsent
        self.experienceLevelRaw = experienceLevel.rawValue
        self.onboardingCompletedAt = onboardingCompletedAt
        self.jurisdictionConfirmedAt = jurisdictionConfirmedAt
        self.educationOnly = educationOnly
        self.createdAt = createdAt
    }

    var residenceType: ResidenceType {
        get { ResidenceType(rawValue: residenceTypeRaw) ?? .singleFamily }
        set { residenceTypeRaw = newValue.rawValue }
    }

    var experienceLevel: ExperienceLevel {
        get { ExperienceLevel(rawValue: experienceLevelRaw) ?? .beginner }
        set { experienceLevelRaw = newValue.rawValue }
    }

    var isOnboarded: Bool { onboardingCompletedAt != nil }

    var rule: JurisdictionRule? { RulePack.rule(forStateCode: stateCode) }

    var jurisdictionLabel: String {
        let place = countyOrCity.trimmingCharacters(in: .whitespacesAndNewlines)
        if place.isEmpty { return stateName }
        return "\(stateName) · \(place)"
    }

    var jurisdictionCode: String { "US-\(stateCode)" }
}
