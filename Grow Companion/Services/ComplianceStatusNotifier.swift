//
//  ComplianceStatusNotifier.swift
//  Grow Companion
//
//  Story 2: when the calculation moves towards a limit, the grower is told.
//  The notification is scheduled only for a worsening status, carries no plant
//  or room name, and says the figure is an estimate rather than legal advice.
//

import Foundation

/// The move from the last stored calculation to the freshly recorded one.
struct ComplianceStatusChange: Equatable {
    let previous: ComplianceLevel
    let current: ComplianceLevel

    /// Only a move towards a limit is worth interrupting the grower for.
    /// Returning inside the limits is good news the app already shows, and an
    /// unknown level is not a status anyone can act on.
    var shouldNotify: Bool {
        guard previous != .unknown, current != .unknown else { return false }
        return current.rank > previous.rank
    }
}

enum ComplianceStatusNotifier {
    /// `nil` for the first calculation, which is the baseline rather than a
    /// change, and for a level the previous snapshot did not have.
    static func change(
        previous: ComplianceLevel?,
        current: ComplianceLevel
    ) -> ComplianceStatusChange? {
        guard let previous else { return nil }
        return ComplianceStatusChange(previous: previous, current: current)
    }

    /// Lock-screen-safe copy: the two levels and nothing about the garden.
    static func notification(for change: ComplianceStatusChange) -> (title: String, body: String) {
        (
            String(localized: "Compliance status changed"),
            String(localized: "You were \(change.previous.title.lowercased()) and are now \(change.current.title.lowercased()). This is an estimate from your local records, not legal advice.")
        )
    }

    static func identifier(for snapshotID: UUID) -> String {
        "compliance-status-\(snapshotID.uuidString)"
    }

    /// Schedules the notification when the status moved towards a limit.
    /// Returns the change it acted on, or `nil` when nothing was scheduled.
    @discardableResult
    static func notifyIfNeeded(
        previous: ComplianceSnapshot?,
        current: ComplianceSnapshot
    ) -> ComplianceStatusChange? {
        guard let change = change(
            previous: previous?.overallLevel,
            current: current.overallLevel
        ), change.shouldNotify else { return nil }

        let content = notification(for: change)
        NotificationSettings.schedule(
            identifier: identifier(for: current.snapshotID),
            category: .compliance,
            title: content.title,
            body: content.body,
            at: current.capturedAt
        )
        return change
    }
}
