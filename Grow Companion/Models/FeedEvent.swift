//
//  FeedEvent.swift
//  Grow Companion
//
//  One watering or feed: volume, pH and EC going in, and the runoff figures
//  when the grower measures them.
//

import Foundation
import SwiftData

@Model
final class FeedEvent {
    var date: Date = Date()
    var kindRaw: String = FeedKind.water.rawValue
    var volumeLiters: Double?
    var phIn: Double?
    var ecIn: Double?
    var phRunoff: Double?
    var ecRunoff: Double?
    var note: String = ""
    var room: Room?

    init(
        date: Date = Date(),
        kind: FeedKind = .water,
        volumeLiters: Double? = nil,
        phIn: Double? = nil,
        ecIn: Double? = nil,
        phRunoff: Double? = nil,
        ecRunoff: Double? = nil,
        note: String = "",
        room: Room? = nil
    ) {
        self.date = date
        self.kindRaw = kind.rawValue
        self.volumeLiters = volumeLiters
        self.phIn = phIn
        self.ecIn = ecIn
        self.phRunoff = phRunoff
        self.ecRunoff = ecRunoff
        self.note = note
        self.room = room
    }

    var kind: FeedKind {
        get { FeedKind(rawValue: kindRaw) ?? .water }
        set { kindRaw = newValue.rawValue }
    }

    var hasMeasurements: Bool {
        volumeLiters != nil || phIn != nil || ecIn != nil || phRunoff != nil || ecRunoff != nil
    }
}
