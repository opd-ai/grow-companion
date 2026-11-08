//
//  LocalizationCatalogTests.swift
//  Grow CompanionTests
//
//  The Spanish catalog is data, so the mistakes that break a build at
//  runtime are wrong placeholders: a value that swaps %lld for %@ crashes the
//  format or prints garbage. These tests read the catalog itself and compare
//  every Spanish value with the key the app looks up.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct LocalizationCatalogTests {
    @Test func catalogParsesWithSpanishForEveryKey() throws {
        let catalog = try loadCatalog()
        let strings = try #require(catalog["strings"] as? [String: Any])

        #expect(catalog["sourceLanguage"] as? String == "en")
        #expect(strings.count > 1200)

        let withoutSpanish = strings.filter { spanishValues(in: $0.value).isEmpty }
        #expect(withoutSpanish.isEmpty, "No Spanish text for \(withoutSpanish.keys.prefix(5))")
    }

    @Test func everySpanishValueKeepsItsPlaceholders() throws {
        let problems = try localizationProblems()

        #expect(problems.isEmpty, "\(problems.prefix(5))")
    }

    @Test func pluralEntriesCarryOneAndOther() throws {
        let catalog = try loadCatalog()
        let strings = try #require(catalog["strings"] as? [String: Any])

        var incomplete: [String] = []
        for (key, raw) in strings {
            guard let entry = raw as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let spanish = localizations["es"] as? [String: Any],
                  let variations = spanish["variations"] as? [String: Any],
                  let plural = variations["plural"] as? [String: Any] else { continue }
            if !Set(plural.keys).isSuperset(of: ["one", "other"]) {
                incomplete.append(key)
            }
        }

        #expect(incomplete.isEmpty, "Incomplete plural forms for \(incomplete.prefix(5))")
    }

    @Test func placeholderScannerIgnoresLiteralPercents() {
        #expect(placeholders(in: "58–62% humidity") == [])
        #expect(placeholders(in: "Below 55% dries too fast") == [])
        #expect(placeholders(in: "No target set") == [])
        #expect(placeholders(in: "%lld plants in %@") == ["%d", "%@"])
        #expect(placeholders(in: "%@: was %@, now %@") == ["%@", "%@", "%@"])
    }

    @Test func shortenedValuesOnlyDropThePluralSuffixArgument() {
        let key = "%lld journal entr%@"

        #expect(placeholderProblem(key: key, value: "%lld entradas del diario") == nil)
        #expect(placeholderProblem(key: key, value: "%@ entradas del diario") != nil)
        #expect(placeholderProblem(key: "%lld days", value: "%lld días y %@") != nil)
    }

    @Test func mismatchedValueIsReported() {
        let catalog: [String: Any] = [
            "strings": [
                "Kept %lld records": [
                    "localizations": [
                        "es": [
                            "stringUnit": [
                                "state": "translated",
                                "value": "Guardó %@ registros"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let problems = localizationProblems(in: catalog)

        #expect(problems.count == 1)
        #expect(problems.first?.contains("Kept %lld records") == true)
    }
}

// MARK: - Catalog access

private func catalogURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Grow Companion")
        .appendingPathComponent("Resources")
        .appendingPathComponent("Localizable.xcstrings")
}

private func loadCatalog() throws -> [String: Any] {
    let url = catalogURL()
    #expect(FileManager.default.fileExists(atPath: url.path), "Missing catalog at \(url.path)")
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data)
    return try #require(object as? [String: Any])
}

private func localizationProblems() throws -> [String] {
    localizationProblems(in: try loadCatalog())
}

private func localizationProblems(in catalog: [String: Any]) -> [String] {
    guard let strings = catalog["strings"] as? [String: Any] else {
        return ["The catalog has no strings table"]
    }

    var problems: [String] = []
    for (key, raw) in strings {
        guard let entry = raw as? [String: Any] else {
            problems.append("The entry for “\(key)” is not an object")
            continue
        }
        let values = spanishValues(in: entry)
        if values.isEmpty {
            problems.append("No Spanish text for “\(key)”")
            continue
        }
        for (label, value) in values {
            if value.isEmpty {
                problems.append("The \(label) of “\(key)” is empty")
            }
            if let problem = placeholderProblem(key: key, value: value) {
                problems.append(problem)
            }
        }
    }
    return problems.sorted()
}

/// The Spanish values of one catalog entry, each labelled with where it sits,
/// so a plural form and a plain value report the same way.
private func spanishValues(in raw: Any) -> [(label: String, value: String)] {
    guard let entry = raw as? [String: Any],
          let localizations = entry["localizations"] as? [String: Any],
          let spanish = localizations["es"] as? [String: Any] else {
        return []
    }

    if let unit = spanish["stringUnit"] as? [String: Any],
       let value = unit["value"] as? String {
        return [("value", value)]
    }

    guard let variations = spanish["variations"] as? [String: Any],
          let plural = variations["plural"] as? [String: Any] else {
        return []
    }

    return plural.compactMap { form, rawForm in
        guard let rawForm = rawForm as? [String: Any],
              let unit = rawForm["stringUnit"] as? [String: Any],
              let value = unit["value"] as? String else { return nil }
        return ("plural.\(form)", value)
    }
}

// MARK: - Placeholders

/// A value may leave out any of the `%@` suffix arguments the English plural
/// trick used, because Spanish supplies the whole noun instead, but every
/// placeholder it keeps must be the one the key expects, in order.
private func placeholderProblem(key: String, value: String) -> String? {
    let expected = placeholders(in: key)
    let actual = placeholders(in: value)

    var index = 0
    for token in expected {
        if index < actual.count, actual[index] == token {
            index += 1
        } else if token == "%@" {
            continue
        } else {
            return "“\(key)” expects \(expected) but its Spanish value has \(actual)"
        }
    }
    return index == actual.count
        ? nil
        : "“\(key)” expects \(expected) but its Spanish value has \(actual)"
}

/// The printf placeholders in a string, normalised to their conversion
/// character so `%lld` and `%d` compare equal. A percent that is not followed
/// by a conversion — the `%` in `58–62% humidity` — is text, not a placeholder.
private func placeholders(in text: String) -> [String] {
    var result: [String] = []
    var index = text.startIndex

    while index < text.endIndex {
        guard text[index] == "%" else {
            index = text.index(after: index)
            continue
        }

        var cursor = text.index(after: index)
        if cursor < text.endIndex, text[cursor] == "%" {
            result.append("%%")
            index = text.index(after: cursor)
            continue
        }

        // A positional argument (`%1$lld`) carries the same conversion as the
        // plain form, so the check compares conversions, not numbering.
        if cursor < text.endIndex, text[cursor].isNumber {
            var probe = cursor
            while probe < text.endIndex, text[probe].isNumber {
                probe = text.index(after: probe)
            }
            if probe < text.endIndex, text[probe] == "$" {
                cursor = text.index(after: probe)
            }
        }

        var conversion: Character?
        while cursor < text.endIndex {
            let next = text[cursor]
            if "-+#0.".contains(next) || next.isNumber || "lhqLztj".contains(next) {
                cursor = text.index(after: cursor)
                continue
            }
            conversion = next
            break
        }

        if let conversion, "@difuxXoOfFeEgGcCsSpaA".contains(conversion) {
            result.append("%" + String(conversion))
            index = text.index(after: cursor)
        } else {
            index = text.index(after: index)
        }
    }

    return result
}
