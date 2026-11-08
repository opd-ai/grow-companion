//
//  RulePack.swift
//  Grow Companion
//
//  Bundled rule pack plus the shared legal copy. A remote, signed pack can
//  replace `rules` later without changing anything that reads this type.
//

import Foundation

enum RulePack {
    static let version = "2025.05.1"
    static let verifiedOn = "2025-05-15"
    static let staleAfterDays = 90

    static let rules: [JurisdictionRule] = JurisdictionData.rules

    static var states: [JurisdictionRule] {
        rules.sorted { $0.stateName < $1.stateName }
    }

    static func rule(forStateCode code: String) -> JurisdictionRule? {
        rules.first { $0.stateCode.caseInsensitiveCompare(code) == .orderedSame }
    }

    static func rule(forStateName name: String) -> JurisdictionRule? {
        rules.first { $0.stateName.caseInsensitiveCompare(name) == .orderedSame }
    }

    static var verifiedDate: Date? {
        parseDate(verifiedOn)
    }

    static func parseDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return dayFormatter.date(from: string)
    }

    static func daysSinceVerified(_ rule: JurisdictionRule, now: Date = Date()) -> Int? {
        guard let date = parseDate(rule.verifiedOn) else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: now).day
    }

    static func isStale(_ rule: JurisdictionRule, now: Date = Date()) -> Bool {
        guard let days = daysSinceVerified(rule, now: now) else { return true }
        return days > staleAfterDays
    }

    static func displayDate(_ string: String?) -> String {
        guard let date = parseDate(string) else { return "Not recorded" }
        return displayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

enum LegalCopy {
    static let federalTitle = "Federal status"

    static let federalStatus = "Cannabis is a Schedule I controlled substance under the federal Controlled Substances Act (21 U.S.C. § 812). State law does not change federal law, and rescheduling has been discussed but not settled. Verify the current federal status before you rely on anything in this app."

    static let federalURL = "https://www.dea.gov/drug-information/drug-scheduling"

    static let scope = "Grow Companion is for personal home cultivation only. It has no marketplace, no sales, no payments, no transfers, no gifting and no shipping. A plant or harvest can be marked retained, consumed at home or destroyed — never sold or given away."

    static let verificationDuty = "You are responsible for verifying the current law where you live. Grow Companion is a record-keeping tool, not a lawyer: a computed total is an estimate from the bundled rule pack, not legal advice. Rules change, and every rule shows the date its text was last updated and links to a primary source where one exists."

    static let ageAttestation = "This app is for adults of legal age to cultivate cannabis where they live — 21 or older in most states that allow home growing. This is a self-attestation, not an identity check: your confirmation is stored on this device as a flag with a timestamp, nothing more. Grow Companion never scans an ID, never sends it anywhere and never stores a date of birth."

    static let privacy = "Everything you record stays on this device unless you export it. Grow Companion has no account, no cloud sync and no analytics, and your records work with no network connection. If you ask the app to suggest your state, that one lookup is handled by Apple's location service and the app keeps only a state or locality name, never coordinates. Photos are re-encoded so location metadata is removed."

    static let educationOnly = "Your jurisdiction does not permit personal home cultivation, so tracking is turned off. You can still read the rules and the guidance in this app."
}
