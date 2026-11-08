//
//  SensorDevice.swift
//  Grow Companion
//
//  A trusted environmental sensor paired to one room.
//

import Foundation
import SwiftData

enum SensorTransport: String, CaseIterable, Codable, Identifiable {
    case bluetooth
    case wifi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bluetooth: return "Bluetooth"
        case .wifi: return "Wi-Fi"
        }
    }

    var systemImage: String {
        switch self {
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .wifi: return "wifi"
        }
    }
}

@Model
final class SensorDevice {
    var name: String = "Room sensor"
    var identifier: String = ""
    var transportRaw: String = SensorTransport.bluetooth.rawValue
    var pairedAt: Date = Date()
    var lastSeenAt: Date?
    var lastReadingAt: Date?
    var isConnected: Bool = false
    var room: Room?

    @Relationship(deleteRule: .cascade, inverse: \EnvironmentReading.sensor)
    var readings: [EnvironmentReading] = []

    init(
        name: String,
        identifier: String,
        transport: SensorTransport,
        pairedAt: Date = Date(),
        room: Room? = nil
    ) {
        self.name = name
        self.identifier = identifier
        self.transportRaw = transport.rawValue
        self.pairedAt = pairedAt
        self.room = room
    }

    var transport: SensorTransport {
        get { SensorTransport(rawValue: transportRaw) ?? .bluetooth }
        set { transportRaw = newValue.rawValue }
    }

    var lastSeenLabel: String {
        guard let lastSeenAt else { return "Never seen" }
        let interval = Date().timeIntervalSince(lastSeenAt)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60)) min ago" }
        if interval < 86400 { return "\(Int(interval / 3600)) hr ago" }
        return Format.shortDate(lastSeenAt)
    }
}
