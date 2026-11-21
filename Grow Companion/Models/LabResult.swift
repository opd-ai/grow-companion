//
//  LabResult.swift
//  Grow Companion
//
//  The figures from a lab report the grower had done, kept exactly as the
//  report printed them. The app never parses, averages or interprets a figure,
//  so nothing here can read as a diagnosis, a verdict or a verified claim.
//

import Foundation
import SwiftData

/// One figure on a report: a name, the value as printed (`18.4`, `<0.1`,
/// `Not detected`), an optional unit, and whether the lab flagged it.
struct LabAnalyte: Codable, Hashable, Identifiable {
    var name: String
    var value: String
    var unit: String
    var flagged: Bool

    init(name: String, value: String, unit: String = "", flagged: Bool = false) {
        self.name = name
        self.value = value
        self.unit = unit
        self.flagged = flagged
    }

    var id: String { "\(name)|\(unit)|\(value)|\(flagged)" }

    /// The value with its unit, exactly as the grower typed it.
    var displayValue: String {
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUnit.isEmpty ? value : "\(value) \(trimmedUnit)"
    }
}

@Model
final class LabResult {
    var reportDate: Date = Date()
    var recordedAt: Date = Date()
    var labName: String = ""
    var notes: String = ""
    /// The figures, stored as the value type they are rather than as columns.
    var analytesData: Data = Data()
    /// The grower typed this from a report they hold, not the app.
    var userConfirmed: Bool = false
    var plant: Plant?

    init(
        reportDate: Date = Date(),
        recordedAt: Date = Date(),
        labName: String = "",
        notes: String = "",
        analytes: [LabAnalyte] = [],
        userConfirmed: Bool = false,
        plant: Plant? = nil
    ) {
        self.reportDate = reportDate
        self.recordedAt = recordedAt
        self.labName = labName
        self.notes = notes
        self.userConfirmed = userConfirmed
        self.plant = plant
        self.analytes = analytes
    }

    var analytes: [LabAnalyte] {
        get { (try? JSONDecoder().decode([LabAnalyte].self, from: analytesData)) ?? [] }
        set { analytesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// The figures the report itself marks as outside a limit. Shown as the
    /// lab's flags, never as the app's judgement.
    var flaggedAnalytes: [LabAnalyte] { analytes.filter(\.flagged) }

    var isEmpty: Bool { analytes.isEmpty && labName.isEmpty && notes.isEmpty }

    var displayName: String {
        let trimmed = labName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Lab report") : trimmed
    }
}
