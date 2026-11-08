//
//  Format.swift
//  Grow Companion
//
//  Units and small display helpers shared by every screen.
//

import Foundation

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }

    var subtitle: String {
        switch self {
        case .metric: return "°C, grams, square metres"
        case .imperial: return "°F, ounces, square feet"
        }
    }
}

enum SettingsKey {
    static let unitSystem = "unitSystem"
    static let warningThreshold = "warningThreshold"

    static let appLockEnabled = "appLockEnabled"
    static let appLockGrace = "appLockGrace"

    static let notificationPriorityPrefix = "notificationPriority."
    static let genericNotificationContent = "genericNotificationContent"
    static let quietHoursEnabled = "quietHoursEnabled"
    static let quietHoursStart = "quietHoursStart"
    static let quietHoursEnd = "quietHoursEnd"

    static let careDigestEnabled = "careDigestEnabled"
    static let careDigestTime = "careDigestTime"
    static let careDigestRoomIDs = "careDigestRoomIDs"

    static let lastBackupDate = "lastBackupDate"
    static let lastBackupIncludesPhotos = "lastBackupIncludesPhotos"

    /// Every preference the app writes, so delete-all can clear all of them.
    static let all: [String] = [
        unitSystem,
        warningThreshold,
        appLockEnabled,
        appLockGrace,
        genericNotificationContent,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
        careDigestEnabled,
        careDigestTime,
        careDigestRoomIDs,
        lastBackupDate,
        lastBackupIncludesPhotos
    ]
}

enum Format {
    static func weight(_ grams: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            if grams >= 1000 {
                return String(format: "%.1f kg", grams / 1000)
            }
            if grams < 10 {
                return String(format: "%.1f g", grams)
            }
            return String(format: "%.0f g", grams)
        case .imperial:
            return String(format: "%.1f oz", grams / 28.3495)
        }
    }

    static func weightLimit(_ grams: Double?, unit: UnitSystem) -> String {
        guard let grams else { return "Not specified" }
        return weight(grams, unit: unit)
    }

    static func area(_ squareMeters: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return String(format: "%.2f m²", squareMeters)
        case .imperial:
            return String(format: "%.1f sq ft", squareMeters * 10.7639)
        }
    }

    static func areaLimit(_ squareMeters: Double?, unit: UnitSystem) -> String {
        guard let squareMeters else { return "Not specified" }
        return area(squareMeters, unit: unit)
    }

    static func dayCount(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }

    static func temperature(_ celsius: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return String(format: "%.1f °C", celsius)
        case .imperial:
            return String(format: "%.1f °F", celsius * 9 / 5 + 32)
        }
    }

    static func temperatureRange(_ range: ClosedRange<Double>, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return String(format: "%.0f–%.0f °C", range.lowerBound, range.upperBound)
        case .imperial:
            let low = range.lowerBound * 9 / 5 + 32
            let high = range.upperBound * 9 / 5 + 32
            return String(format: "%.0f–%.0f °F", low, high)
        }
    }

    static func volume(_ liters: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return String(format: "%.2f L", liters)
        case .imperial:
            return String(format: "%.2f gal", liters * 0.264172)
        }
    }

    static func shortDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
