//
//  CureBurp.swift
//  Grow Companion
//

import Foundation
import SwiftData

@Model
final class CureBurp {
    var date: Date = Date()
    var note: String = ""
    var session: DryingSession?

    init(date: Date = Date(), note: String = "", session: DryingSession? = nil) {
        self.date = date
        self.note = note
        self.session = session
    }
}
