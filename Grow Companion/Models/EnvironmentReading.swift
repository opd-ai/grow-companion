enum EnvironmentReadingSource: String, Codable {
    case manual
    case sensor
}


//
//  EnvironmentReading.swift
//  Grow Companion
//
//  One manual temperature, humidity or light reading for a room. Raw readings
//  are kept for 30 days, then folded into hourly averages by the care log.
//

import Foundation
import SwiftData

@Model
final class EnvironmentReading {
    var date: Date = Date()
    var temperatureC: Double?
    var humidityPercent: Double?
    var lightPPFD: Double?
    var isHourlyAverage: Bool = false
    var sampleCount: Int = 1
    var sourceRaw: String = EnvironmentReadingSource.manual.rawValue
    var room: Room?
    var sensor: SensorDevice?

    init(
        date: Date = Date(),
        temperatureC: Double? = nil,
        humidityPercent: Double? = nil,
        lightPPFD: Double? = nil,
        isHourlyAverage: Bool = false,
        sampleCount: Int = 1,
        source: EnvironmentReadingSource = .manual,
        room: Room? = nil,
        sensor: SensorDevice? = nil
    ) {
        self.date = date
        self.temperatureC = temperatureC
        self.humidityPercent = humidityPercent
        self.lightPPFD = lightPPFD
        self.isHourlyAverage = isHourlyAverage
        self.sampleCount = sampleCount
        self.sourceRaw = source.rawValue
        self.room = room
        self.sensor = sensor
    }

    var source: EnvironmentReadingSource {
        get { EnvironmentReadingSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var isEmpty: Bool {
        temperatureC == nil && humidityPercent == nil && lightPPFD == nil
    }

    var isAnyOutOfRange: Bool {
        if let temperatureC, let range = room?.targetTemperatureRange, !range.contains(temperatureC) {
            return true
        }
        if let humidityPercent, let range = room?.targetHumidityRange, !range.contains(humidityPercent) {
            return true
        }
        return false
    }
}
