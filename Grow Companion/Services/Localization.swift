//
//  Localization.swift
//  Grow Companion
//
//  Interface copy is being translated to Spanish (Mexico). Legal, rule and
//  verification text stays in English until a qualified legal localisation
//  review exists, and while the app runs in Spanish it says so.
//

import Foundation

enum Localization {
    /// Shown only when the app is running in Spanish, which is when the
    /// English legal text would otherwise look like an oversight.
    static var legalTextNotice: String? {
        guard Locale.current.language.languageCode == .spanish else { return nil }
        return String(
            localized: "Legal and rule text stays in English until a reviewed Spanish translation exists."
        )
    }
}
