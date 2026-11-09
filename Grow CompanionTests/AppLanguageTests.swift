//
//  AppLanguageTests.swift
//  Grow CompanionTests
//
//  English is the language the app opens in, a stored choice wins, and the
//  choice is handed to the bundle and kept out of the way of delete-all.
//

import Foundation
import Testing
@testable import Grow_Companion

@Suite(.serialized)
struct AppLanguageTests {
    @Test func englishIsTheDefaultWhateverTheDeviceLanguageIs() throws {
        let defaults = try suiteDefaults()

        let store = AppLanguageStore(defaults: defaults)

        #expect(store.language == .english)
        #expect(defaults.string(forKey: SettingsKey.appLanguage) == "en")
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["en"])
    }

    @Test func aStoredChoiceIsKeptAcrossLaunches() throws {
        let defaults = try suiteDefaults()
        defaults.set("es", forKey: SettingsKey.appLanguage)

        let store = AppLanguageStore(defaults: defaults)

        #expect(store.language == .spanish)
    }

    @Test func choosingSpanishHandsItToTheBundle() throws {
        let defaults = try suiteDefaults()
        let store = AppLanguageStore(defaults: defaults)

        store.select(.spanish)

        #expect(store.language == .spanish)
        #expect(defaults.string(forKey: SettingsKey.appLanguage) == "es")
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["es"])
    }

    @Test func anUnknownStoredValueFallsBackToEnglish() throws {
        let defaults = try suiteDefaults()
        defaults.set("fr", forKey: SettingsKey.appLanguage)

        let store = AppLanguageStore(defaults: defaults)

        #expect(store.language == .english)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["en"])
    }

    @Test func localizationIdentifiersMapToTheLanguagesTheAppShips() {
        #expect(AppLanguage(localizationIdentifier: "es-MX") == .spanish)
        #expect(AppLanguage(localizationIdentifier: "es") == .spanish)
        #expect(AppLanguage(localizationIdentifier: "en-GB") == .english)
        #expect(AppLanguage(localizationIdentifier: "fr") == nil)
    }

    @Test func eachLanguageCarriesItsOwnLocaleAndName() {
        #expect(AppLanguage.english.locale.identifier == "en")
        #expect(AppLanguage.spanish.locale.identifier == "es")
        #expect(AppLanguage.english.endonym == "English")
        #expect(AppLanguage.spanish.endonym == "Español")
    }

    @Test func eachLanguageDescribesWhatChoosingItDoes() {
        #expect(!AppLanguage.english.detail.isEmpty)
        #expect(!AppLanguage.spanish.detail.isEmpty)
        #expect(AppLanguage.english.detail != AppLanguage.spanish.detail)
    }

    @Test func theRelaunchStateFollowsWhetherTheBundleHasCaughtUp() throws {
        let defaults = try suiteDefaults()
        let store = AppLanguageStore(defaults: defaults, launchLanguage: .english)

        #expect(store.needsRelaunch == false)

        store.select(.spanish)
        #expect(store.needsRelaunch)

        // Choosing the launch language again settles the interface without
        // another launch, so the notice goes away.
        store.select(.english)
        #expect(store.needsRelaunch == false)
    }

    @Test func aBundleAlreadyInTheChosenLanguageNeedsNoRelaunch() throws {
        let defaults = try suiteDefaults()
        defaults.set("es", forKey: SettingsKey.appLanguage)

        let store = AppLanguageStore(defaults: defaults, launchLanguage: .spanish)

        #expect(store.language == .spanish)
        #expect(store.needsRelaunch == false)
    }

    @Test func theBundleIsGivenOneLanguageAndNothingElse() throws {
        let defaults = try suiteDefaults()
        let store = AppLanguageStore(defaults: defaults, launchLanguage: .english)

        // A list left over from the device's own settings is replaced, not
        // extended: the bundle must resolve the grower's single choice.
        defaults.set(["en", "es"], forKey: "AppleLanguages")

        store.select(.spanish)

        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["es"])
    }

    @Test func deleteAllClearsTheLanguageChoice() {
        #expect(SettingsKey.all.contains(SettingsKey.appLanguage))
    }

    @Test func theLegalNoticeIsShownOnlyInSpanish() {
        #expect(Localization.legalTextNotice(appLanguage: .english) == nil)
        #expect(Localization.legalTextNotice(appLanguage: .spanish) != nil)
    }
}

/// A throwaway defaults domain, so these tests never touch the app's own
/// preferences or the `AppleLanguages` list the device is running on.
private func suiteDefaults() throws -> UserDefaults {
    let name = "AppLanguageTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return defaults
}
