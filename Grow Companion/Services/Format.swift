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
        case .metric: return String(localized: "Metric")
        case .imperial: return String(localized: "Imperial")
        }
    }

    var subtitle: String {
        switch self {
        case .metric: return String(localized: "°C, grams, square metres")
        case .imperial: return String(localized: "°F, ounces, square feet")
        }
    }
}

enum SettingsKey {
    static let unitSystem = "unitSystem"
    static let warningThreshold = "warningThreshold"

    /// The interface language. English until the grower chooses Spanish.
    static let appLanguage = "appLanguage"

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

    static let quickLogRoomName = "quickLogRoomName"
    static let quickLogPlantName = "quickLogPlantName"

    /// Widgets show counts only unless the grower turns task names on.
    static let widgetShowsTaskTitles = "widgetShowsTaskTitles"

    /// The lessons the grower has marked as read. Listed here so delete-all
    /// clears it with every other preference.
    static let educationCompletedLessons = "education.completedLessonIDs"

    /// Every preference the app writes, so delete-all can clear all of them.
    static let all: [String] = [
        unitSystem,
        warningThreshold,
        appLanguage,
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
        lastBackupIncludesPhotos,
        quickLogRoomName,
        quickLogPlantName,
        widgetShowsTaskTitles,
        educationCompletedLessons
    ]
}

enum Format {
    /// The locale numbers and dates are rendered in. It follows the interface
    /// language the grower chose, so a Spanish interface sees Spanish
    /// separators, month names and date order whatever the phone is set to;
    /// tests set it to prove that a language is honoured.
    static var locale: Locale = .current

    static func weight(_ grams: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            if grams >= 1000 {
                return number(grams / 1000, digits: 1) + " kg"
            }
            if grams < 10 {
                return number(grams, digits: 1) + " g"
            }
            return number(grams, digits: 0) + " g"
        case .imperial:
            return number(grams / 28.3495, digits: 1) + " oz"
        }
    }

    static func weightLimit(_ grams: Double?, unit: UnitSystem) -> String {
        guard let grams else { return String(localized: "Not specified") }
        return weight(grams, unit: unit)
    }

    static func area(_ squareMeters: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return number(squareMeters, digits: 2) + " m²"
        case .imperial:
            return number(squareMeters * 10.7639, digits: 1) + " ft²"
        }
    }

    static func areaLimit(_ squareMeters: Double?, unit: UnitSystem) -> String {
        guard let squareMeters else { return String(localized: "Not specified") }
        return area(squareMeters, unit: unit)
    }

    static func dayCount(_ days: Int) -> String {
        days == 1
            ? String(localized: "1 day")
            : String(localized: "\(days) days")
    }

    static func temperature(_ celsius: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return number(celsius, digits: 1) + " °C"
        case .imperial:
            return number(celsius * 9 / 5 + 32, digits: 1) + " °F"
        }
    }

    static func temperatureRange(_ range: ClosedRange<Double>, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return number(range.lowerBound, digits: 0) + "–" + number(range.upperBound, digits: 0) + " °C"
        case .imperial:
            let low = range.lowerBound * 9 / 5 + 32
            let high = range.upperBound * 9 / 5 + 32
            return number(low, digits: 0) + "–" + number(high, digits: 0) + " °F"
        }
    }

    static func volume(_ liters: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return number(liters, digits: 2) + " L"
        case .imperial:
            return number(liters * 0.264172, digits: 2) + " gal"
        }
    }

    static func shortDate(_ date: Date) -> String {
        dateFormatter.locale = locale
        return dateFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.locale = locale
        return timeFormatter.string(from: date)
    }

    static func percent(_ value: Double) -> String {
        number(value * 100, digits: 0) + "%"
    }

    /// A number in the current locale: a Spanish (Spain) device sees `24,5`
    /// and an English one `24.5`, and neither is hard-coded here.
    static func number(_ value: Double, digits: Int) -> String {
        numberFormatter.locale = locale
        numberFormatter.minimumFractionDigits = digits
        numberFormatter.maximumFractionDigits = digits
        return numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.roundingMode = .halfUp
        return formatter
    }()

    /// The locale's medium date: `Nov 7, 2026` in English, `7 nov 2026` in
    /// Spanish. The old fixed `d MMM yyyy` pattern is gone.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
