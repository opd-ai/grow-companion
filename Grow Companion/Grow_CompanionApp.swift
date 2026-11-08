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

    var body: some Scene {
        WindowGroup {
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
    }
}
