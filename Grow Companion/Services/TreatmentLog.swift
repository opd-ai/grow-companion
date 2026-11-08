//
//  TreatmentLog.swift
//  Grow Companion
//
//  Display helpers for treatment records.
//

import Foundation

enum TreatmentLog {
    static func withdrawalText(_ treatment: Treatment) -> String? {
        guard let end = treatment.withdrawalEndDate else { return nil }
        return String(localized: "Withdrawal ends \(Format.shortDate(end))")
    }

    static func activeWithdrawal(for plant: Plant) -> Treatment? {
        plant.allTreatments
            .filter(\.isWithdrawalActive)
            .sorted { ($0.withdrawalEndDate ?? .distantPast) > ($1.withdrawalEndDate ?? .distantPast) }
            .first
    }
}
