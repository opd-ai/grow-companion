//
//  Localization.swift
//  Grow Companion
//
//  The interface is translated to Spanish (Mexico) and opens in English. Legal,
//  rule and verification text stays in English until a qualified legal
//  localisation review exists, and while the interface is in Spanish it says so.
//

import Foundation

enum Localization {
    /// Shown only while the interface is in Spanish, which is when the English
    /// legal text would otherwise look like an oversight.
    static func legalTextNotice(appLanguage: AppLanguage) -> String? {
        guard appLanguage == .spanish else { return nil }
        return String(
            localized: "Legal and rule text stays in English until a reviewed Spanish translation exists."
        )
    }
}
