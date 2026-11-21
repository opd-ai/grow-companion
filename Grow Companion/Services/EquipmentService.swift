//
//  EquipmentService.swift
//  Grow Companion
//
//  Writing, editing and removing equipment and its service records. One place
//  decides what "last serviced" means, so logging a backfilled service never
//  rewinds the schedule the grower is on, and removing a record leaves the date
//  following the history that is still there.
//

import Foundation
import SwiftData

/// What deleting one piece of equipment takes with it, for the confirmation.
struct EquipmentRemovalSummary: Equatable {
    let serviceRecords: Int
}

enum EquipmentServiceError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let detail):
            return String(localized: "The equipment was not changed: \(detail)")
        }
    }
}

enum EquipmentService {
    static func summary(for equipment: Equipment) -> EquipmentRemovalSummary {
        EquipmentRemovalSummary(serviceRecords: equipment.serviceRecords.count)
    }

    /// The latest service on record, or nil when the history is empty.
    static func latestServiceDate(in records: [ServiceRecord]) -> Date? {
        records.map(\.date).max()
    }

    /// Records one completed service. "Last serviced" only ever moves forward,
    /// so a service logged after the fact cannot rewind the next due date.
    @discardableResult
    static func add(
        date: Date,
        note: String,
        to equipment: Equipment,
        in context: ModelContext
    ) throws -> ServiceRecord {
        let record = ServiceRecord(date: date, note: note, equipment: equipment)
        context.insert(record)

        if date > equipment.lastServicedAt {
            equipment.lastServicedAt = date
        }

        try save(context)
        return record
    }

    /// Edits one service record and re-derives the schedule from the history,
    /// so correcting a date moves the next service with it.
    static func update(
        _ record: ServiceRecord,
        date: Date,
        note: String,
        in context: ModelContext
    ) throws {
        record.date = date
        record.note = note

        if let equipment = record.equipment,
           let latest = latestServiceDate(in: equipment.serviceRecords) {
            equipment.lastServicedAt = latest
        }

        try save(context)
    }

    /// Removes one service record. The schedule follows the services that are
    /// left; when none are, the stored date is the grower's own value and is
    /// left alone rather than invented.
    static func delete(_ record: ServiceRecord, in context: ModelContext) throws {
        let equipment = record.equipment
        let remaining = equipment?.serviceRecords.filter { $0 !== record } ?? []

        context.delete(record)

        if let equipment, let latest = latestServiceDate(in: remaining) {
            equipment.lastServicedAt = latest
        }

        try save(context)
    }

    /// Removes the equipment and its service history. The history is deleted
    /// explicitly rather than left to the cascade rule, so a failed save cannot
    /// leave records behind that belong to nothing.
    static func delete(_ equipment: Equipment, in context: ModelContext) throws {
        let records = Array(equipment.serviceRecords)
        for record in records {
            context.delete(record)
        }
        context.delete(equipment)
        try save(context)
    }

    private static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw EquipmentServiceError.saveFailed(error.localizedDescription)
        }
    }
}
