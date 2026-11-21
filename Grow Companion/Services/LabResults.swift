//
//  LabResults.swift
//  Grow Companion
//
//  Writing and validating the figures a grower types from a lab report. Every
//  save needs the grower's confirmation that they copied the report, and every
//  figure keeps the text the report printed, so the app never invents a value
//  by parsing one.
//

import Foundation
import SwiftData

/// What the editor holds before saving.
struct LabResultDraft: Equatable {
    var reportDate: Date = Date()
    var labName: String = ""
    var notes: String = ""
    var analytes: [LabAnalyte] = []
    var userConfirmed: Bool = false
}

enum LabResultError: LocalizedError {
    case notConfirmed
    case noFigures
    case tooManyFigures
    case nameTooLong
    case valueTooLong
    case detailsTooLong
    case futureDate
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfirmed:
            return String(localized: "Confirm that you copied these figures from a report you hold.")
        case .noFigures:
            return String(localized: "Add at least one figure with a name and a value.")
        case .tooManyFigures:
            return String(localized: "A report can hold up to \(LabResultService.maximumAnalytes) figures.")
        case .nameTooLong:
            return String(localized: "A figure name or the lab name is too long.")
        case .valueTooLong:
            return String(localized: "A figure value is too long.")
        case .detailsTooLong:
            return String(localized: "The notes or a unit are too long.")
        case .futureDate:
            return String(localized: "A report cannot be dated in the future.")
        case .saveFailed(let detail):
            return String(localized: "The report was not saved: \(detail)")
        }
    }
}

enum LabResultService {
    static let maximumAnalytes = 30
    static let maximumNameLength = 60
    static let maximumValueLength = 40
    static let maximumUnitLength = 20
    static let maximumLabNameLength = 80
    static let maximumNotesLength = 2000

    /// Trims, drops the rows that are still empty, and refuses anything the
    /// screen would otherwise have to apologise for later.
    static func validated(_ draft: LabResultDraft, now: Date = Date()) throws -> LabResultDraft {
        guard draft.userConfirmed else { throw LabResultError.notConfirmed }

        let labName = draft.labName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard labName.count <= maximumLabNameLength else { throw LabResultError.nameTooLong }

        let notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard notes.count <= maximumNotesLength else { throw LabResultError.detailsTooLong }

        guard draft.reportDate <= now else { throw LabResultError.futureDate }

        var figures: [LabAnalyte] = []
        for row in draft.analytes {
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = row.value.trimmingCharacters(in: .whitespacesAndNewlines)
            // A row the grower started and left empty is not an error.
            guard !name.isEmpty, !value.isEmpty else { continue }

            guard name.count <= maximumNameLength else { throw LabResultError.nameTooLong }
            guard value.count <= maximumValueLength else { throw LabResultError.valueTooLong }

            let unit = row.unit.trimmingCharacters(in: .whitespacesAndNewlines)
            guard unit.count <= maximumUnitLength else { throw LabResultError.detailsTooLong }

            figures.append(LabAnalyte(name: name, value: value, unit: unit, flagged: row.flagged))
        }

        guard !figures.isEmpty else { throw LabResultError.noFigures }
        guard figures.count <= maximumAnalytes else { throw LabResultError.tooManyFigures }

        return LabResultDraft(
            reportDate: draft.reportDate,
            labName: labName,
            notes: notes,
            analytes: figures,
            userConfirmed: true
        )
    }

    @discardableResult
    static func save(
        _ draft: LabResultDraft,
        existing: LabResult?,
        for plant: Plant,
        in context: ModelContext,
        now: Date = Date()
    ) throws -> LabResult {
        let valid = try validated(draft, now: now)

        let result: LabResult
        if let existing {
            result = existing
        } else {
            let created = LabResult(plant: plant)
            context.insert(created)
            result = created
        }

        result.reportDate = valid.reportDate
        result.labName = valid.labName
        result.notes = valid.notes
        result.analytes = valid.analytes
        result.userConfirmed = true
        result.plant = plant

        do {
            try context.save()
        } catch {
            context.rollback()
            throw LabResultError.saveFailed(error.localizedDescription)
        }

        return result
    }

    static func delete(_ result: LabResult, in context: ModelContext) throws {
        context.delete(result)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw LabResultError.saveFailed(error.localizedDescription)
        }
    }

    /// Newest report first.
    static func sorted(_ results: [LabResult]) -> [LabResult] {
        results.sorted { $0.reportDate > $1.reportDate }
    }
}
