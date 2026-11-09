//
//  Grow_CompanionApp.swift
//  Grow Companion
//

import SwiftUI
import SwiftData

@main
struct Grow_CompanionApp: App {
    @State private var appLock = AppLock()
    @State private var boot = StoreBoot()

    /// English until the grower chooses Spanish, applied to the whole
    /// interface and to the numbers and dates inside it.
    @State private var language = AppLanguageStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = boot.container {
                    ContentView()
                        .environment(appLock)
                        .modelContainer(container)
                } else {
                    // The store could not be opened, so it is not shown as an empty
                    // grow. Recovery keeps the unreadable files and never creates a
                    // silent in-memory substitute for the user's records.
                    StoreRecoveryView(boot: boot)
                        .environment(appLock)
                }
            }
            .environment(language)
            .environment(\.locale, language.language.locale)
            .onChange(of: language.language, initial: true) { _, newValue in
                // Weights, dates and times in the records follow the same
                // choice as the copy around them.
                Format.locale = newValue.locale
            }
        }
    }
}
