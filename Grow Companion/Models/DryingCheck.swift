//
//  DryingCheck.swift
//  Grow Companion
//

import Foundation
import SwiftData

@Model
final class DryingCheck {
    var date: Date = Date()
    var humidityPercent: Double?
    var temperatureC: Double?
    var stemSnapRaw: String?
    var note: String = ""
    var session: DryingSession?

    init(
        date: Date = Date(),
        humidityPercent: Double? = nil,
        temperatureC: Double? = nil,
        stemSnap: StemSnap? = nil,
        note: String = "",
        session: DryingSession? = nil
    ) {
        self.date = date
        self.humidityPercent = humidityPercent
        self.temperatureC = temperatureC
        self.stemSnapRaw = stemSnap?.rawValue
        self.note = note
        self.session = session
    }

    var stemSnap: StemSnap? {
        get {
            guard let raw = stemSnapRaw else { return nil }
            return StemSnap(rawValue: raw)
        }
        set { stemSnapRaw = newValue?.rawValue }
    }
}
