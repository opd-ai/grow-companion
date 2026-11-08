//
//  SensorConnectionService.swift
//  Grow Companion
//
//  Validates timestamps before a trusted sensor can write to the environment log.
//

import Foundation
import SwiftData

struct SensorReadingPayload {
    let timestamp: Date
    let temperatureC: Double?
    let humidityPercent: Double?
    let lightPPFD: Double?
}

enum SensorReadingError: LocalizedError {
    case stale
    case replayed
    case empty

    var errorDescription: String? {
        switch self {
        case .stale: return "This reading is too old to trust and was not saved."
        case .replayed: return "This timestamp was already received and was not saved again."
        case .empty: return "The sensor sent no supported environmental values."
        }
    }
}

enum SensorConnectionService {
    static let maximumReadingAge: TimeInterval = 5 * 60

    @discardableResult
    static func ingest(
        _ payload: SensorReadingPayload,
        from sensor: SensorDevice,
        room: Room,
        context: ModelContext,
        now: Date = Date()
    ) throws -> EnvironmentReading {
        guard payload.temperatureC != nil || payload.humidityPercent != nil || payload.lightPPFD != nil else {
            throw SensorReadingError.empty
        }
        guard payload.timestamp <= now,
              now.timeIntervalSince(payload.timestamp) <= maximumReadingAge else {
            throw SensorReadingError.stale
        }
        if let last = sensor.lastReadingAt, payload.timestamp <= last {
            throw SensorReadingError.replayed
        }

        let reading = EnvironmentReading(
            date: payload.timestamp,
            temperatureC: payload.temperatureC,
            humidityPercent: payload.humidityPercent,
            lightPPFD: payload.lightPPFD,
            source: .sensor,
            room: room,
            sensor: sensor
        )
        context.insert(reading)
        sensor.lastReadingAt = payload.timestamp
        sensor.lastSeenAt = now
        sensor.isConnected = true
        try context.save()
        return reading
    }

    static func disconnect(_ sensor: SensorDevice, context: ModelContext) {
        sensor.isConnected = false
        sensor.room = nil
        try? context.save()
    }
}
