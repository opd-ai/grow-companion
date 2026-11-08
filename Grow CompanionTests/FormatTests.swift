//
//  FormatTests.swift
//  Grow CompanionTests
//
//  Numbers, dates and units follow the locale instead of a hard-coded
//  English pattern, while the grower's metric or imperial choice still wins.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct FormatLocaleTests {
    @Test func englishNumbering() {
        let restore = Format.locale
        Format.locale = Locale(identifier: "en_US")
        defer { Format.locale = restore }

        #expect(Format.weight(125, unit: .metric) == "125 g")
        #expect(Format.weight(1200, unit: .metric) == "1.2 kg")
        #expect(Format.weight(1.5, unit: .metric) == "1.5 g")
        #expect(Format.area(2.5, unit: .metric) == "2.50 m²")
        #expect(Format.temperature(24.5, unit: .metric) == "24.5 °C")
        #expect(Format.temperatureRange(18...24, unit: .metric) == "18–24 °C")
        #expect(Format.volume(2.5, unit: .metric) == "2.50 L")
        #expect(Format.percent(0.8) == "80%")
    }

    @Test func spanishNumberingUsesTheLocaleSeparators() {
        let restore = Format.locale
        Format.locale = Locale(identifier: "es_ES")
        defer { Format.locale = restore }

        #expect(Format.weight(1.5, unit: .metric) == "1,5 g")
        #expect(Format.area(2.5, unit: .metric) == "2,50 m²")
        #expect(Format.temperature(24.5, unit: .metric) == "24,5 °C")
        #expect(Format.volume(2.5, unit: .metric) == "2,50 L")
    }

    @Test func imperialUnitsAreConvertedBeforeFormatting() {
        let restore = Format.locale
        Format.locale = Locale(identifier: "en_US")
        defer { Format.locale = restore }

        #expect(Format.weight(28.3495, unit: .imperial) == "1.0 oz")
        #expect(Format.temperature(0, unit: .imperial) == "32.0 °F")
        #expect(Format.area(1, unit: .imperial) == "10.8 ft²")
    }

    @Test func datesFollowTheLocale() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 7
        components.hour = 9
        let date = try #require(Calendar(identifier: .gregorian).date(from: components))

        let restore = Format.locale
        defer { Format.locale = restore }

        Format.locale = Locale(identifier: "en_US")
        let english = Format.shortDate(date)

        Format.locale = Locale(identifier: "es_MX")
        let spanish = Format.shortDate(date)

        #expect(english.contains("2026"))
        #expect(spanish.contains("2026"))
        #expect(english != spanish)
    }

    @Test func dayCountsAreSingularised() {
        #expect(Format.dayCount(1) == "1 day")
        #expect(Format.dayCount(3) == "3 days")
    }
}
