//
//  ShareGrant.swift
//  Grow Companion
//
//  On-device record of a scoped, read-only share configuration.
//

import Foundation
import SwiftData

@Model
final class ShareGrant {
    var recipientName: String = ""
    var roomNamesRaw: String = ""
    var plantNamesRaw: String = ""
    var categoriesRaw: String = ""
    var createdAt: Date = Date()
    var expiresAt: Date = Date()
    var revokedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ShareAccessLog.grant)
    var accessLogs: [ShareAccessLog] = []

    init(
        recipientName: String,
        roomNames: [String],
        plantNames: [String],
        categories: [String],
        createdAt: Date = Date(),
        expiresAt: Date
    ) {
        self.recipientName = recipientName
        self.roomNamesRaw = roomNames.joined(separator: "\u{001F}")
        self.plantNamesRaw = plantNames.joined(separator: "\u{001F}")
        self.categoriesRaw = categories.joined(separator: "\u{001F}")
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    var roomNames: [String] { roomNamesRaw.split(separator: "\u{001F}").map(String.init) }
    var plantNames: [String] { plantNamesRaw.split(separator: "\u{001F}").map(String.init) }
    var categories: [String] { categoriesRaw.split(separator: "\u{001F}").map(String.init) }
    var isRevoked: Bool { revokedAt != nil }
    var isExpired: Bool { Date() >= expiresAt }
    var isActive: Bool { !isRevoked && !isExpired }
    var scopeSummary: String {
        let count = roomNames.count + plantNames.count
        let categoriesText = String(localized: "\(categories.count) categories")
        return String(localized: "\(count) selected \(count == 1 ? "scope" : "scopes") · \(categoriesText)")
    }
}

@Model
final class ShareAccessLog {
    var date: Date = Date()
    var action: String = "Created"
    var grant: ShareGrant?

    init(date: Date = Date(), action: String, grant: ShareGrant? = nil) {
        self.date = date
        self.action = action
        self.grant = grant
    }
}
