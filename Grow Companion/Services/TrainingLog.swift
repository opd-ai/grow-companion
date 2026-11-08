//
//  TrainingLog.swift
//  Grow Companion
//
//  Small display helpers for training sessions.
//

import Foundation

enum TrainingLog {
    /// "today", "yesterday" or "12 days ago".
    static func relativeText(_ date: Date, now: Date = Date()) -> String {
        let days = HarvestLog.dayCount(since: date, now: now)
        switch days {
        case 0: return "today"
        case 1: return "yesterday"
        default: return "\(days) days ago"
        }
    }

    static func nodesText(_ nodes: Int?) -> String? {
        guard let nodes, nodes > 0 else { return nil }
        return "\(nodes) node\(nodes == 1 ? "" : "s")"
    }
}
