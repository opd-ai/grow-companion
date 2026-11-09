//
//  AppLanguage.swift
//  Grow Companion
//
//  The language the interface is read in. English is the language the app
//  opens in on every device, whatever the phone is set to; the grower can
//  choose Spanish (Mexico) during onboarding or later in Settings. The choice
//  is remembered and handed to the bundle, so the interface and the bundle
//  agree from the next launch on.
//

import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case english = "en"
    case spanish = "es"

    /// The language the app opens in before the grower has chosen one. English
    /// is the default on every device, not whatever the phone is set to.
    static let defaultLanguage: AppLanguage = .english

    var id: String { rawValue }

    /// The interface copy, together with the dates and numbers that go with it.
    var locale: Locale { Locale(identifier: rawValue) }

    /// The two-letter code shown ahead of the name in the language list.
    var shortCode: String { rawValue.uppercased() }

    /// The language's own name, deliberately never translated: a grower who
    /// cannot read the current interface still has to find their own language.
    var endonym: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    /// One line saying what choosing this language gives the grower. Only the
    /// name above stays in its own language; this line is read in the interface
    /// language in use, so each choice is explained in the language the grower
    /// is reading.
    var detail: String {
        switch self {
        case .english:
            return String(localized: "Interface, notices and reports in English")
        case .spanish:
            return String(localized: "Interface, notices and reports in Spanish (Mexico)")
        }
    }

    /// `es-MX` and `es` both read as Spanish, `en-GB` as English, and `fr` as
    /// nothing this app ships.
    init?(localizationIdentifier: String) {
        let code = localizationIdentifier
            .split(separator: "-")
            .first
            .map(String.init) ?? localizationIdentifier
        self.init(rawValue: code.lowercased())
    }
}

/// The grower's language choice, remembered across launches.
@Observable
final class AppLanguageStore {
    /// The language the interface is read in.
    private(set) var language: AppLanguage

    /// The language this process's bundle resolves strings in. `Text` follows
    /// the interface at once, but `String(localized:)` and anything else the
    /// bundle resolves keep this language until the app is opened again, so
    /// while the two disagree the interface says the rest is on its way.
    private let launchLanguage: AppLanguage

    private let defaults: UserDefaults

    /// True while some of the interface still needs the next launch to follow
    /// the chosen language.
    var needsRelaunch: Bool {
        language != launchLanguage
    }

    /// The list iOS reads to decide which `.lproj` a bundle resolves. Writing
    /// it is how a choice made in the app reaches `String(localized:)` and the
    /// system text the app shows.
    private static let systemLanguageKey = "AppleLanguages"

    /// - Parameters:
    ///   - defaults: where the choice is remembered. The tests pass a throwaway
    ///     domain so they never touch the app's own preferences.
    ///   - launchLanguage: the language this process's bundle resolves. The live
    ///     app reads it from the bundle; the tests inject it, so the state of a
    ///     relaunch can be proved without relaunching anything.
    init(defaults: UserDefaults = .standard, launchLanguage: AppLanguage? = nil) {
        self.defaults = defaults

        let stored = defaults.string(forKey: SettingsKey.appLanguage)
        language = stored.flatMap(AppLanguage.init(rawValue:)) ?? .defaultLanguage
        self.launchLanguage = launchLanguage ?? Self.bundleLanguage

        apply()
    }

    /// Remembers a choice and hands it to the bundle.
    func select(_ newLanguage: AppLanguage) {
        guard newLanguage != language else { return }

        language = newLanguage
        apply()
    }

    private func apply() {
        if defaults.string(forKey: SettingsKey.appLanguage) != language.rawValue {
            defaults.set(language.rawValue, forKey: SettingsKey.appLanguage)
        }

        if defaults.stringArray(forKey: Self.systemLanguageKey) != [language.rawValue] {
            defaults.set([language.rawValue], forKey: Self.systemLanguageKey)
        }
    }

    /// The language the bundle in this process resolves, taken from the
    /// localizations it prefers right now.
    private static var bundleLanguage: AppLanguage {
        let identifier = Bundle.main.preferredLocalizations.first
            ?? AppLanguage.defaultLanguage.rawValue
        return AppLanguage(localizationIdentifier: identifier) ?? .defaultLanguage
    }
}
